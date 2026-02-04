defmodule Realms.Commands.Drop do
  @moduledoc """
  Drop command - drops an item from inventory to the room.
  """
  @behaviour Realms.Commands.Command

  alias Realms.Game
  alias Realms.Messaging

  defstruct [:item_name]

  @impl true
  def parse("drop " <> item_name) do
    name = String.trim(item_name)
    if name == "", do: :error, else: {:ok, %__MODULE__{item_name: name}}
  end

  def parse(_), do: :error

  @impl true
  def execute(%__MODULE__{item_name: name}, context) do
    player = Game.get_player!(context.player_id)
    room = player.current_room
    items = Game.list_items_in_player(player)

    case find_item(items, name) do
      nil ->
        Messaging.send_to_player(player.id, "<red>You aren't carrying '#{name}'.</>")

      item ->
        case Game.move_item_to_room(item, room) do
          {:ok, _} ->
            Messaging.send_to_player(player.id, "<green>You drop #{item.name}.</>")

            Messaging.send_to_room(
              room.id,
              "<yellow>#{player.name}</> drops <cyan>#{item.name}</>.",
              exclude: player.id
            )

          {:error, _} ->
            Messaging.send_to_player(player.id, "<red>You can't drop that.</>")
        end
    end

    :ok
  end

  @impl true
  def description, do: "Drop an item"

  @impl true
  def examples, do: ["drop sword", "drop torch"]

  defp find_item(items, name) do
    search_term = String.downcase(name)

    Enum.find(items, fn item ->
      item.name
      |> String.downcase()
      |> String.split()
      |> Enum.any?(fn word -> String.starts_with?(word, search_term) end)
    end)
  end
end
