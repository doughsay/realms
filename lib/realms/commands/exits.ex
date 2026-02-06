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
    {:ok, %{exits: exits}} = fetch(context)

    case exits do
      [] ->
        Messaging.send_to_player(context.player_id, "<gray>Obvious exits: </><gray-light>none</>")

      exits ->
        exit_list = exits |> Enum.map(& &1.direction) |> Enum.sort() |> Enum.join(", ")

        Messaging.send_to_player(
          context.player_id,
          "<gray>Obvious exits: </><bright-cyan>#{exit_list}</>"
        )
    end

    :ok
  end

  @impl true
  def description, do: "List available exits"

  @impl true
  def examples, do: ["exits"]

  # Private helpers

  defp fetch(context) do
    Game.tx(fn ->
      player = Game.get_player!(context.player_id)
      exits = Game.list_exits_from_room(player.current_room_id)

      {:ok, %{exits: exits}}
    end)
  end
end
