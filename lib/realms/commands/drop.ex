defmodule Realms.Commands.Drop do
  @moduledoc """
  Drop command - drops an item from inventory to the room.
  """
  @behaviour Realms.Commands.Command

  alias Realms.Commands.Command
  alias Realms.Commands.Utils
  alias Realms.Game
  alias Realms.Messaging

  defstruct [:item_name]

  @impl Command
  def parse("drop " <> item_name) do
    name = String.trim(item_name)
    if name == "", do: :error, else: {:ok, %__MODULE__{item_name: name}}
  end

  def parse(_), do: :error

  @impl Command
  def execute(%__MODULE__{item_name: name}, context) do
    case drop_item(context.player_id, name) do
      {:ok, %{player: player, room: room, item: item}} ->
        Messaging.send_to_player(player.id, "<green>You drop #{item.name}.</>")

        Messaging.send_to_room(
          room.id,
          "<yellow>#{player.name}</> drops <cyan>#{item.name}</>.",
          exclude: player.id
        )

      {:error, :no_matching_item} ->
        Messaging.send_to_player(context.player_id, "<red>You aren't carrying '#{name}'.</>")
    end

    :ok
  end

  @impl Command
  def description, do: "Drop an item"

  @impl Command
  def examples, do: ["drop sword", "drop torch"]

  # Private helpers

  defp drop_item(player_id, search_term) do
    Game.tx(fn ->
      player = Game.get_player!(player_id)
      room = Game.get_room!(player.current_room_id)
      items = Game.list_items_in_player(player)

      with {:ok, item} <- Utils.match_item(items, search_term) do
        {:ok, _} = Game.move_item_to_room(item, room)

        {:ok, %{player: player, room: room, item: item}}
      end
    end)
  end
end
