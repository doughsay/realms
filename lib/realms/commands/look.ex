defmodule Realms.Commands.Look do
  @moduledoc """
  Look command - shows the current room description.
  """

  @behaviour Realms.Commands.Command

  alias Realms.Commands.Command
  alias Realms.Game
  alias Realms.Messaging

  defstruct []

  @impl Command
  def parse("look"), do: {:ok, %__MODULE__{}}
  def parse(_), do: :error

  @impl Command
  def execute(%__MODULE__{}, context) do
    {:ok,
     %{
       player: player,
       room: room,
       other_players: other_players,
       mobs: mobs,
       exits: exits,
       items: items
     }} = fetch(context)

    Messaging.send_to_player(
      player.id,
      """
      <bright-yellow:b>#{room.name}</>
      <white>#{room.description}</>

      #{format_exits(exits)}
      #{format_items(items)}\
      #{format_beings(mobs, other_players)}
      """
    )

    :ok
  end

  @impl Command
  def description, do: "Show current room description"

  @impl Command
  def examples, do: ["look"]

  # Private helpers

  defp fetch(context) do
    Game.tx(fn ->
      player = Game.get_player!(context.player_id)
      room = Game.get_room!(player.current_room_id)

      other_players =
        Game.players_in_room(room.id)
        |> Enum.reject(&(&1.id == context.player_id))

      mobs = Game.mobs_in_room(room.id)
      exits = Game.list_exits_from_room(room.id)
      items = Game.list_items_in_room(room)

      {:ok,
       %{
         player: player,
         room: room,
         other_players: other_players,
         mobs: mobs,
         exits: exits,
         items: items
       }}
    end)
  end

  defp format_exits([]) do
    "<gray>Obvious exits: </><gray-light>none</>"
  end

  defp format_exits(exits) do
    exit_list = exits |> Enum.map(& &1.direction) |> Enum.sort() |> Enum.join(", ")
    "<gray>Obvious exits: </><bright-cyan>#{exit_list}</>"
  end

  defp format_items([]), do: ""

  defp format_items(items) do
    colored =
      Enum.map(items, fn item -> "<bright-cyan>#{item.name}</>" end)

    "\nYou see #{prose_join(colored)}."
  end

  defp format_beings([], []), do: ""

  defp format_beings(mobs, players) do
    mob_names = Enum.map(mobs, &{&1.name, "<bright-yellow>#{&1.name}</>"})

    player_names =
      Enum.map(players, fn player ->
        suffix =
          if player.connection_status == :away do
            " <gray-light:i>(staring off into space)</>"
          else
            ""
          end

        {player.name, "<bright-green>#{player.name}</>#{suffix}"}
      end)

    colored =
      (mob_names ++ player_names)
      |> Enum.sort_by(&elem(&1, 0))
      |> Enum.map(&elem(&1, 1))

    verb = if length(colored) == 1, do: "is", else: "are"
    "\n#{prose_join(colored)} #{verb} here."
  end

  defp prose_join([single]), do: single
  defp prose_join([a, b]), do: "#{a} and #{b}"

  defp prose_join(list) do
    {leading, [last]} = Enum.split(list, -1)
    Enum.join(leading, ", ") <> ", and " <> last
  end
end
