defmodule Realms.Commands.Look do
  @moduledoc """
  Look command - shows the current room description.
  """

  @behaviour Realms.Commands.Command

  alias Realms.Game
  alias Realms.Messaging

  defstruct []

  @impl true
  def parse("look"), do: {:ok, %__MODULE__{}}
  def parse(_), do: :error

  @impl true
  def execute(%__MODULE__{}, context) do
    player = Game.get_player!(context.player_id)
    room = player.current_room

    other_players =
      Game.players_in_room(room.id)
      |> Enum.reject(&(&1.id == context.player_id))

    exits = Game.list_exits_from_room(room.id)
    items = Game.list_items_in_room(room)

    Messaging.send_to_player(
      player.id,
      """
      <bright-yellow:b>#{room.name}</>
      <white>#{room.description}</>

      #{format_exits_section(exits)}#{format_items_section(items)}#{format_players_section(other_players)}
      """
    )

    :ok
  end

  @impl true
  def description, do: "Show current room description"

  @impl true
  def examples, do: ["look"]

  # Private helpers

  defp format_items_section([]), do: ""

  defp format_items_section(items) do
    item_lines =
      Enum.map_join(items, "", fn item ->
        "\n<gray>• </><bright-cyan>#{item.name}</> is here."
      end)

    "\n<gray>Items:</>" <> item_lines <> "\n"
  end

  defp format_exits_section([]) do
    "<gray>Obvious exits: </><gray-light>none</>\n"
  end

  defp format_exits_section(exits) do
    exit_list = exits |> Enum.map(& &1.direction) |> Enum.sort() |> Enum.join(", ")
    "<gray>Obvious exits: </><bright-cyan>#{exit_list}</>\n"
  end

  defp format_players_section([]), do: ""

  defp format_players_section(players) do
    player_lines =
      Enum.map_join(players, "", fn player ->
        suffix =
          if player.connection_status == :away do
            " <gray-light:i>(staring off into space)</>"
          else
            ""
          end

        "\n<gray>• </><bright-green>#{player.name}</>#{suffix}"
      end)

    "\n<gray>Also here:</>" <> player_lines <> "\n"
  end
end
