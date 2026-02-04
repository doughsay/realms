defmodule Realms.Commands.Exits do
  @moduledoc """
  Exits command - lists available exits from the current room.
  """

  @behaviour Realms.Commands.Command

  alias Realms.Game
  alias Realms.Messaging
  alias Realms.Messaging.Message

  defstruct []

  @impl true
  def parse("exits"), do: {:ok, %__MODULE__{}}
  def parse(_), do: :error

  @impl true
  def execute(%__MODULE__{}, context) do
    player = Game.get_player!(context.player_id)
    room = player.current_room

    exit_text = format_exits(room)
    message = Message.from_text(exit_text, :cyan)
    Messaging.send_to_player(context.player_id, message)

    :ok
  end

  @impl true
  def description, do: "List available exits"

  @impl true
  def examples, do: ["exits"]

  # Private helpers

  defp format_exits(room) do
    exits = Game.list_exits_from_room(room.id)

    if exits == [] do
      "Obvious exits: none"
    else
      exit_list = exits |> Enum.map(& &1.direction) |> Enum.sort() |> Enum.join(", ")
      "Obvious exits: #{exit_list}"
    end
  end
end
