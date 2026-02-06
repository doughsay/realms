defmodule Realms.Commands.Examine do
  @moduledoc """
  Examine command - shows description of an item and its contents (if any).
  """
  @behaviour Realms.Commands.Command

  alias Realms.Commands.Utils
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
    case fetch(context.player_id, name) do
      {:ok, %{item: item, contents: contents}} ->
        message = """
        <bright-cyan:b>#{item.name}</>
        <white>#{item.description}</>
        #{format_contents(contents)}
        """

        Messaging.send_to_player(context.player_id, message)

      {:error, :no_matching_item} ->
        Messaging.send_to_player(context.player_id, "<red>You don't see '#{name}' here.</>")
    end

    :ok
  end

  @impl true
  def description, do: "Examine an item"

  @impl true
  def examples, do: ["examine sword", "x bag"]

  defp fetch(player_id, name) do
    Game.tx(fn ->
      player = Game.get_player!(player_id)
      room = Game.get_room!(player.current_room_id)

      inventory_items = Game.list_items_in_player(player)
      room_items = Game.list_items_in_room(room)

      with {:ok, item} <- Utils.match_item(inventory_items ++ room_items, name) do
        contents = Game.list_items_in_item(item)
        {:ok, %{item: item, contents: contents}}
      end
    end)
  end

  defp format_contents([]), do: "\n<white>It is empty.</>"

  defp format_contents(items) do
    item_list =
      Enum.map_join(items, "\n", fn item ->
        "<gray>• </><green>#{item.name}</>"
      end)

    "\n<white>It contains:</>\n" <> item_list
  end
end
