defmodule Realms.Commands.Examine do
  @moduledoc """
  Examine command - shows description of an item and its contents (if any).
  """
  @behaviour Realms.Commands.Command

  alias Realms.Game
  alias Realms.Messaging

  defstruct [:item_name]

  @impl true
  def parse("examine " <> item_name) do
    name = String.trim(item_name)
    if name == "", do: :error, else: {:ok, %__MODULE__{item_name: name}}
  end

  def parse("x " <> item_name) do
    name = String.trim(item_name)
    if name == "", do: :error, else: {:ok, %__MODULE__{item_name: name}}
  end

  def parse(_), do: :error

  @impl true
  def execute(%__MODULE__{item_name: name}, context) do
    player = Game.get_player!(context.player_id)
    room = player.current_room

    # Look in inventory first, then in the room
    inventory_items = Game.list_items_in_player(player)
    room_items = Game.list_items_in_room(room)

    case find_item(inventory_items ++ room_items, name) do
      nil ->
        Messaging.send_to_player(player.id, "<red>You don't see '#{name}' here.</>")

      item ->
        contents = Game.list_items_in_item(item)

        message = """
        <bright-cyan:b>#{item.name}</>
        <white>#{item.description}</>
        #{format_contents(contents)}
        """

        Messaging.send_to_player(player.id, message)
    end

    :ok
  end

  @impl true
  def description, do: "Examine an item"

  @impl true
  def examples, do: ["examine sword", "x bag"]

  defp find_item(items, name) do
    search_term = String.downcase(name)

    Enum.find(items, fn item ->
      item.name
      |> String.downcase()
      |> String.split()
      |> Enum.any?(fn word -> String.starts_with?(word, search_term) end)
    end)
  end

  defp format_contents([]), do: ""

  defp format_contents(items) do
    item_list =
      Enum.map_join(items, "\n", fn item ->
        "<gray>• </><green>#{item.name}</>"
      end)

    "\n<white>It contains:</>\n" <> item_list
  end
end
