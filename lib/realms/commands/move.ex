defmodule Realms.Commands.Move do
  @moduledoc """
  Move command - moves the player in a direction.
  """

  @behaviour Realms.Commands.Command

  alias Realms.Commands.Command
  alias Realms.Commands.Look
  alias Realms.Game
  alias Realms.Messaging
  alias Realms.PlayerServer

  defstruct [:direction]

  @directions ~w(north south east west northeast northwest southeast southwest up down in out)

  @impl Command
  def parse(direction) when direction in @directions do
    {:ok, %__MODULE__{direction: direction}}
  end

  def parse(_), do: :error

  @impl Command
  def execute(%__MODULE__{direction: direction}, context) do
    case move_player(context.player_id, direction) do
      {:ok, player, new_room, old_room_id} ->
        PlayerServer.change_room_subscription(context.player_id, old_room_id, new_room.id)

        # Departure message to old room
        Messaging.send_to_room(
          old_room_id,
          "<bright-cyan>#{player.name}</><cyan> goes #{direction}.</>",
          exclude: context.player_id
        )

        # Arrival message to new room
        reverse_dir = reverse_direction(direction)

        Messaging.send_to_room(
          new_room.id,
          "<bright-cyan>#{player.name}</><cyan> arrives from #{reverse_dir}.</>",
          exclude: context.player_id
        )

        Look.execute(%Look{}, context)

        :ok

      {:error, :no_exit} ->
        Messaging.send_to_player(context.player_id, "<red>You can't go that way.</>")
        :ok
    end
  end

  @impl Command
  def description, do: "Move in a direction"

  @impl Command
  def examples, do: ["north", "south", "up", "down"]

  # Private helpers

  defp move_player(player_id, direction) do
    Game.tx(fn ->
      player = Game.get_player!(player_id)
      old_room_id = player.current_room_id

      case Game.move_player(player, direction) do
        {:ok, new_room} ->
          {:ok, player, new_room, old_room_id}

        {:error, :no_exit} ->
          {:error, :no_exit}
      end
    end)
  end

  defp reverse_direction("north"), do: "the south"
  defp reverse_direction("south"), do: "the north"
  defp reverse_direction("east"), do: "the west"
  defp reverse_direction("west"), do: "the east"
  defp reverse_direction("northeast"), do: "the southwest"
  defp reverse_direction("northwest"), do: "the southeast"
  defp reverse_direction("southeast"), do: "the northwest"
  defp reverse_direction("southwest"), do: "the northeast"
  defp reverse_direction("up"), do: "below"
  defp reverse_direction("down"), do: "above"
  defp reverse_direction("in"), do: "outside"
  defp reverse_direction("out"), do: "inside"
  defp reverse_direction(_), do: "somewhere"
end
