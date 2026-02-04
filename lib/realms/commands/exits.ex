defmodule Realms.Commands.Exits do
  @moduledoc """
  Exits command - lists available exits from the current room.
  """

  @behaviour Realms.Commands.Command

  alias Realms.Game
  alias Realms.Messaging

  defstruct []

  @impl true
  def parse("exits"), do: {:ok, %__MODULE__{}}
  def parse(_), do: :error

  @impl true
  def execute(%__MODULE__{}, context) do
    player = Game.get_player!(context.player_id)
    room = player.current_room
    exits = Game.list_exits_from_room(room.id)

    message =
      if exits == [] do
        "<gray>Obvious exits: </><gray-light>none</>"
      else
        exit_list = exits |> Enum.map(& &1.direction) |> Enum.sort() |> Enum.join(", ")
        "<gray>Obvious exits: </><bright-cyan>#{exit_list}</>"
      end

    Messaging.send_to_player(context.player_id, message)

    :ok
  end

  @impl true
  def description, do: "List available exits"

  @impl true
  def examples, do: ["exits"]
end
