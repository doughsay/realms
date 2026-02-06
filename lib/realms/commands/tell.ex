defmodule Realms.Commands.Tell do
  @moduledoc """
  Tell command - send private message to online player
  """

  @behaviour Realms.Commands.Command

  alias Realms.Game
  alias Realms.Messaging

  defstruct [:target, :message]

  @usage "usage: tell \\<target> \\<message>"

  @impl true
  def parse("tell " <> command_text) do
    command_text
    |> String.trim_leading()
    |> String.split(~r/\s+/, parts: 2)
    |> case do
      [target, rest] -> {:ok, %__MODULE__{target: target, message: rest}}
      _ -> {:usage, @usage}
    end
  end

  def parse("tell"), do: {:usage, @usage}

  def parse(_), do: :error

  @impl true
  def execute(%__MODULE__{target: target_name, message: message}, context) do
    case resolve_target(context.player_id, target_name) do
      {:ok, %{sender: sender, target: target}} ->
        Messaging.send_to_player(
          target.id,
          "<bright-cyan>#{sender.name}</><gray> tells you: </><white>#{message}</>"
        )

        Messaging.send_to_player(
          sender.id,
          "<gray>You tell </><bright-cyan>#{target.name}</><gray>: </><white>#{message}</>"
        )

      {:error, :not_found} ->
        Messaging.send_to_player(
          context.player_id,
          "<red>Cannot find \"#{target_name}\" online.</>"
        )

      {:error, :ambiguous} ->
        Messaging.send_to_player(
          context.player_id,
          "<red>Multiple matching players. You'll have to be more specific.</>"
        )
    end

    :ok
  end

  @impl true
  def description, do: "Send private message to player if they're online."

  @impl true
  def examples, do: ["tell barfos meet at the tavern", "tell shopkeep deals please"]

  # Private helpers

  defp resolve_target(player_id, target_name) do
    Game.tx(fn ->
      sender = Game.get_player!(player_id)

      case Game.online_players_by_name_prefix(target_name) do
        [target] -> {:ok, %{sender: sender, target: target}}
        [] -> {:error, :not_found}
        _ -> {:error, :ambiguous}
      end
    end)
  end
end
