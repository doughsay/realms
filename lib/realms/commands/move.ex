defmodule Realms.Commands.Move do
  @moduledoc """
  Move command - moves the player in a direction.
  """

  @behaviour Realms.Commands.Command

  alias Realms.Commands.Look
  alias Realms.Game
  alias Realms.Messaging
  alias Realms.Messaging.MessageBuilder
  alias Realms.PlayerServer

  defstruct [:direction]

  @directions ~w(north south east west northeast northwest southeast southwest up down in out)

  @impl true
  def parse(direction) when direction in @directions do
    {:ok, %__MODULE__{direction: direction}}
  end

  def parse(_), do: :error

  @impl true
  def execute(%__MODULE__{direction: direction}, context) do
    player = Game.get_player!(context.player_id)
    old_room_id = player.current_room_id

    case Game.move_player(player, direction) do
      {:ok, new_room} ->
        PlayerServer.change_room_subscription(context.player_id, old_room_id, new_room.id)

        # Departure message to old room
        departure_msg =
          MessageBuilder.new()
          |> MessageBuilder.text(player.name, :bright_cyan)
          |> MessageBuilder.text(" leaves to the #{direction}.", :cyan)
          |> MessageBuilder.build()

        Messaging.send_to_room(old_room_id, departure_msg, exclude: context.player_id)

        # Arrival message to new room
        reverse_dir = reverse_direction(direction)

        arrival_msg =
          MessageBuilder.new()
          |> MessageBuilder.text(player.name, :bright_cyan)
          |> MessageBuilder.text(" arrives from the #{reverse_dir}.", :cyan)
          |> MessageBuilder.build()

        Messaging.send_to_room(new_room.id, arrival_msg, exclude: context.player_id)

        Look.execute(%Look{}, context)

        :ok

      {:error, :no_exit} ->
        msg = MessageBuilder.simple("You can't go that way.", :red)
        Messaging.send_to_player(context.player_id, msg)
        :ok
    end
  end

  @impl true
  def description, do: "Move in a direction"

  @impl true
  def examples, do: ["north", "south", "up", "down"]

  # Private helpers

  defp reverse_direction("north"), do: "south"
  defp reverse_direction("south"), do: "north"
  defp reverse_direction("east"), do: "west"
  defp reverse_direction("west"), do: "east"
  defp reverse_direction("northeast"), do: "southwest"
  defp reverse_direction("northwest"), do: "southeast"
  defp reverse_direction("southeast"), do: "northwest"
  defp reverse_direction("southwest"), do: "northeast"
  defp reverse_direction("up"), do: "below"
  defp reverse_direction("down"), do: "above"
  defp reverse_direction("in"), do: "outside"
  defp reverse_direction("out"), do: "inside"
  defp reverse_direction(_), do: "somewhere"
end
