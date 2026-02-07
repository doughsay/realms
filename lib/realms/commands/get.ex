defmodule Realms.Commands.Get do
  @moduledoc """
  Get command - picks up an item from the room.
  """
  @behaviour Realms.Commands.Command

  alias Realms.Game
  alias Realms.Messaging

  defstruct [:item_name]

  @impl true
  def parse("get " <> item_name) do
    name = String.trim(item_name)
    if name == "", do: :error, else: {:ok, %__MODULE__{item_name: name}}
  end

  def parse(_), do: :error

  @impl true
  def execute(%__MODULE__{item_name: name}, context) do
    case get_item(context.player_id, name) do
      {:ok, %{player: player, room: room, item: item}} ->
        Messaging.send_to_player(player.id, "<green>You pick up #{item.name}.</>")

        Messaging.send_to_room(
          room.id,
          "<yellow>#{player.name}</> picks up <cyan>#{item.name}</>.",
          exclude: player.id
        )

      {:error, :no_matching_item} ->
        Messaging.send_to_player(context.player_id, "<red>You don't see '#{name}' here.</>")

      {:error, :ambiguous} ->
        Messaging.send_to_player(
          context.player_id,
          "<red>Multiple items match '#{name}'. Be more specific.</>"
        )
    end

    :ok
  end

  @impl true
  def description, do: "Pick up an item from the room"

  @impl true
  def examples, do: ["get sword"]

  # Private helpers

  defp get_item(player_id, search_term) do
    Game.tx(fn ->
      player = Game.get_player!(player_id)
      room = Game.get_room!(player.current_room_id)

      with {:ok, item} <- Game.find_item_in_inventory(room.inventory_id, search_term) do
        {:ok, _} = Game.move_item_to_player(item, player)
        {:ok, %{player: player, room: room, item: item}}
      end
    end)
  end
end
