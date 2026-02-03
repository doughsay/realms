defmodule Realms.Commands.Exits do
  @moduledoc """
  Exits command - lists available exits from the current room.
  """

  @behaviour Realms.Commands.Command

  alias Realms.Game
  alias Realms.Messaging
  alias Realms.Messaging.MessageBuilder

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
        MessageBuilder.new()
        |> MessageBuilder.text("Obvious exits: ", :gray)
        |> MessageBuilder.text("none", :gray_light)
        |> MessageBuilder.build()
      else
        exit_list = exits |> Enum.map(& &1.direction) |> Enum.sort() |> Enum.join(", ")

        MessageBuilder.new()
        |> MessageBuilder.text("Obvious exits: ", :gray)
        |> MessageBuilder.text(exit_list, :bright_cyan)
        |> MessageBuilder.build()
      end

    Messaging.send_to_player(context.player_id, message)

    :ok
  end

  @impl true
  def description, do: "List available exits"

  @impl true
  def examples, do: ["exits"]
end
