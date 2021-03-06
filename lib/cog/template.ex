defmodule Cog.Template do
  alias Cog.Queries
  alias Cog.Repo
  alias Cog.TemplateCache

  @fallback_adapter "any"

  def render(adapter, template, context),
    do: render(adapter, nil, template, context)
  def render(adapter, bundle_version_id, template, context) do
    with {:ok, template_fun} <- fetch_compiled_fun(adapter, bundle_version_id, template, context) do
      template_fun.(context)
    end
  end

  # First try to pull the template out of the cache and return it. If it's not
  # found, fetch the source, compile and store the template before returning.
  defp fetch_compiled_fun(adapter, bundle_version_id, template, context) do
    with :error              <- TemplateCache.lookup(adapter, bundle_version_id, template),
         {:ok, source}       <- fetch_source(adapter, bundle_version_id, template, context),
         {:ok, template_fun} <- compile(source),
         :ok                 <- TemplateCache.insert(adapter, bundle_version_id, template, template_fun),
         do: {:ok, template_fun}
  end

  # Always use the raw template when responding to the test adapter.
  # Used in integration tests.
  defp fetch_source("test", _bundle_version_id, _template, context) do
    fetch_source(@fallback_adapter, nil, "raw", context)
  end

  defp fetch_source(adapter, bundle_version_id, nil, context) do
    fetch_source(adapter, bundle_version_id, default_template(context), context)
  end

  # We check for fallback templates in the following order:
  #
  # 1. Fetch the exact template
  # 2. Fetch a generic template for the adapter
  # 3. Fetch a generic template for the "any" adapter
  defp fetch_source(adapter, bundle_version_id, template, _context) do
    with {:error, :template_not_found} <- fetch(adapter, bundle_version_id, template),
         {:error, :template_not_found} <- fetch(adapter, nil, template),
         {:error, :template_not_found} <- fetch(@fallback_adapter, nil, template),
         do: {:error, :template_not_found}
  end

  defp compile(source) do
    case FuManchu.Compiler.compile(source) do
      {:ok, template_fun} ->
        {:ok, wrap_template_fun(template_fun)}
      error ->
        error
    end
  end

  defp fetch(adapter, bundle_version_id, template) do
    source = Queries.Template.template_source(adapter, bundle_version_id, template)
    |> Repo.one

    case source do
      nil ->
        {:error, :template_not_found}
      source ->
        {:ok, source}
    end
  end

  defp wrap_template_fun(fun) do
    fn context ->
      try do
        output = fun.(%{context: context, partials: partials})
        {:ok, output}
      rescue
        error ->
          {:error, error}
      end
    end
  end

  defp partials do
    %{json: &render_json/1,
      text: &render_text/1}
  end

  defp render_json(context),
    do: Poison.encode!(context, pretty: true)

  defp render_text(%{"body" => body}) when is_list(body),
    do: Enum.join(body, "\n")
  defp render_text(%{"body" => body}) when is_binary(body),
    do: body
  defp render_text(text) when is_binary(text),
    do: text

  defp default_template(%{"body" => _}),                  do: "text"
  defp default_template(context) when is_binary(context), do: "text"
  defp default_template(context) when is_map(context),    do: "json"
  defp default_template(_),                               do: "raw"
end
