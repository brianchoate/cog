defmodule Cog.Commands.Alias.Create do
  alias Cog.Repo
  alias Cog.Commands.Helpers
  alias Cog.Models.UserCommandAlias

  @moduledoc """
  Create new aliases. Subcommand for alias.

  USAGE
    alias create <alias-name> <alias-definition>

  EXAMPLE
    alias create my-awesome-alias "echo \"My awesome alias\""
    > Success, 'user:my-awesome-alias' has been created
  """

  @doc """
  Entry point. Creates an alias.
  Takes a cog request and argument list.
  returns {:ok, <msg>} on success and {:error, <err>} on error.
  """
  def create_new_user_command_alias(req, arg_list) do
    case Helpers.get_args(arg_list, 2) do
      {:ok, [alias_name, pipeline]} ->
        params = %{name: alias_name, pipeline: pipeline, user_id: req.user["id"]}
        changeset = UserCommandAlias.changeset(%UserCommandAlias{}, params)

        case Repo.insert(changeset) do
          {:ok, command_alias} ->
            {:ok, "alias-create", Helpers.jsonify(command_alias)}
          {:error, %{errors: errors}} ->
            {:error, {:db_errors, errors}}
        end
      error ->
        error
    end
  end
end
