defmodule Realms.Commands.Look do
  @moduledoc """
  Look command - shows the current room description.
  """

  @behaviour Realms.Commands.Command

  alias Realms.Game
  alias Realms.Messaging
  alias Realms.Messaging.MessageBuilder

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

    message =
      MessageBuilder.new()
      |> MessageBuilder.bold(room.name, :bright_yellow)
      |> MessageBuilder.newline()
      |> MessageBuilder.text(room.description, :white)
      |> MessageBuilder.paragraph()
      |> add_exits(exits)
      |> MessageBuilder.add_if(other_players != [], fn builder ->
        builder
        |> MessageBuilder.paragraph()
        |> add_players(other_players)
      end)
      |> MessageBuilder.build()

    Messaging.send_to_player(player.id, message)
    :ok
  end

  @impl true
  def description, do: "Show current room description"

  @impl true
  def examples, do: ["look"]

  # Private helpers

  defp add_exits(builder, []) do
    builder
    |> MessageBuilder.text("Obvious exits: ", :gray)
    |> MessageBuilder.text("none", :gray_light)
  end

  defp add_exits(builder, exits) do
    exit_list = exits |> Enum.map(& &1.direction) |> Enum.sort() |> Enum.join(", ")

    builder
    |> MessageBuilder.text("Obvious exits: ", :gray)
    |> MessageBuilder.text(exit_list, :bright_cyan)
  end

  defp add_players(builder, players) do
    builder = MessageBuilder.text(builder, "Also here:", :gray)

    Enum.reduce(players, builder, fn player, builder ->
      builder
      |> MessageBuilder.newline()
      |> MessageBuilder.text("  • ", :gray)
      |> MessageBuilder.text(player.name, :bright_green)
      |> MessageBuilder.add_if(player.connection_status == :away, fn b ->
        MessageBuilder.italic(b, " (staring off into space)", :gray_light)
      end)
    end)
  end
end
