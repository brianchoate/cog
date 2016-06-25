defmodule Cog.Commands.Relay do
  use Cog.Command.GenCommand.Base, bundle: Cog.embedded_bundle
  alias Cog.Commands.Relay

  require Cog.Commands.Helpers, as: Helpers

  @description "Manage relays"

  Helpers.usage :root, """
  #{@description}

  USAGE
    relay [FLAGS] <subcommand>

  FLAGS
    -h, --help  Display this usage info

  SUBCOMMANDS
    info      Get information on a specific relay
    list      Lists relays and their status (default)
    update    Update the name or description of a relay

  """
  permission "manage_relays"

  rule "when command is #{Cog.embedded_bundle}:relay must have #{Cog.embedded_bundle}:manage_relays"

  # list options
  option "group", type: "bool", short: "g"
  option "verbose", type: "bool", short: "v"

  # update options
  option "name", type: "string"
  option "description", type: "string"

  def handle_message(req, state) do
    {subcommand, args} = Helpers.get_subcommand(req.args)

    result = case subcommand do
               "info" ->
                 Relay.Info.info(req, args)
               "list" ->
                 Relay.List.list_relays(req)
               "update" ->
                 Relay.Update.update_relay(req, args)
               nil ->
                 if Helpers.flag?(req.options, "help") do
                   show_usage
                 else
                   Relay.List.list_relays(req)
                 end
               invalid ->
                 {:error, {:unknown_subcommand, invalid}}
             end

    case result do
      {:ok, template, data} ->
        {:reply, req.reply_to, template, data, state}
      {:ok, message} ->
        {:reply, req.reply_to, message, state}
      {:error, err} ->
        {:error, req.reply_to, error(err), state}
    end
  end

  defp error(:wrong_type),
    do: "Arguments must be strings"
  defp error(error),
    do: Helpers.error(error)
end
