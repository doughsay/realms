defmodule Realms.Commands.Look do
  @moduledoc """
  Look command - shows the current room description.
  """

  @behaviour Realms.Commands.Command

  import Realms.Messaging.Message

  alias Realms.Game
  alias Realms.Messaging
  alias Realms.Messaging.Message

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

    room_msg = ~m"""
    {bright-yellow:b}#{room.name}{/}
    {white}#{room.description}{/}

    """

    exits_msg = get_exits_message(exits)
    players_msg = get_players_message(other_players)

    all_segments = room_msg.segments ++ exits_msg.segments ++ players_msg.segments
    message = Message.new(all_segments)

    Messaging.send_to_player(player.id, message)
    :ok
  end

  @impl true
  def description, do: "Show current room description"

  @impl true
  def examples, do: ["look"]

  # Private helpers

  defp get_exits_message([]) do
    ~m"{gray}Obvious exits: {/}{gray-light}none{/}"
  end

  defp get_exits_message(exits) do
    exit_list = exits |> Enum.map(& &1.direction) |> Enum.sort() |> Enum.join(", ")
    ~m"{gray}Obvious exits: {/}{bright-cyan}#{exit_list}{/}"
  end

  defp get_players_message([]), do: ~m""

  defp get_players_message(players) do
    header = ~m"""


    {gray}Also here:{/}
    """

    player_segments =
      Enum.flat_map(players, fn player ->
        suffix =
          if player.connection_status == :away,
            do: ~m" {gray-light:i}(staring off into space){/}",
            else: ~m""

        line = ~m"""

        {gray}  • {/}{bright-green}#{player.name}{/}
        """

        line.segments ++ suffix.segments
      end)

    Message.new(header.segments ++ player_segments)
  end
end
