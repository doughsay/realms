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
  def execute(%__MODULE__{target: target, message: message}, context) do
    myself = context.player_id

    case Game.online_players_by_name_prefix(target) do
      [player] ->
        Messaging.send_to_player(player.id, message)
        Messaging.send_to_player(myself, message)

      [] ->
        Messaging.send_to_player(myself, "Cannot find \"#{target}\" online")

      _ ->
        Messaging.send_to_player(
          myself,
          "Multiple matching players. You'll have to be more specific."
        )
    end

    :ok
  end

  @impl true
  def description, do: "Send private message to player if they're online."

  @impl true
  def examples, do: ["tell barfos meet at the tavern", "tell shopkeep deals please"]
end
