defmodule Realms.Commands.Look do
  @moduledoc """
  Look command - shows the current room description.
  """

  @behaviour Realms.Commands.Command

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

    content = """
    #{room.name}
    #{room.description}

    #{format_exits(room)}
    """

    Messaging.send_to_player(player.id, Message.new(:room, content))

    if other_players != [] do
      player_list = format_player_list(other_players)
      Messaging.send_to_player(player.id, Message.new(:players, "Also here: #{player_list}"))
    end

    :ok
  end

  @impl true
  def description, do: "Show current room description"

  @impl true
  def examples, do: ["look"]

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

  defp format_player_list(players) do
    Enum.map_join(players, ", ", fn player ->
      if player.connection_status == :away do
        "#{player.name} (staring off into space)"
      else
        player.name
      end
    end)
  end
end
