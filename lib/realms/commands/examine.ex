defmodule Realms.Commands.Examine do
  @moduledoc """
  Examine command - shows description of an item, mob, or player.
  """
  @behaviour Realms.Commands.Command

  alias Realms.Game
  alias Realms.Messaging

  defstruct [:target]

  @impl true
  def parse("examine " <> target) do
    name = String.trim(target)
    if name == "", do: :error, else: {:ok, %__MODULE__{target: name}}
  end

  def parse("x " <> target) do
    name = String.trim(target)
    if name == "", do: :error, else: {:ok, %__MODULE__{target: name}}
  end

  def parse(_), do: :error

  @impl true
  def execute(%__MODULE__{target: name}, context) do
    case fetch(context.player_id, name) do
      {:ok, {:item, item, contents}} ->
        message = """
        <bright-cyan:b>#{item.name}</>
        <white>#{item.description}</>
        #{format_contents(contents)}
        """

        Messaging.send_to_player(context.player_id, message)

      {:ok, {:mob, mob}} ->
        message = """
        <bright-yellow:b>#{mob.long_name}</>
        <white>#{mob.description}</>
        """

        Messaging.send_to_player(context.player_id, message)

      {:ok, {:player, player}} ->
        message = """
        <bright-green:b>#{player.name}</>
        <white>You see nothing particularly special about #{player.name}.</>
        """

        Messaging.send_to_player(context.player_id, message)

      {:error, :not_found} ->
        Messaging.send_to_player(context.player_id, "<red>You don't see '#{name}' here.</>")
    end

    :ok
  end

  @impl true
  def description, do: "Examine an item, NPC, or player"

  @impl true
  def examples, do: ["examine sword", "x bag", "examine tim"]

  defp fetch(player_id, name) do
    Game.tx(fn ->
      player = Game.get_player!(player_id)
      room = Game.get_room!(player.current_room_id)

      find_item(player, room, name) ||
        find_mob(room, name) ||
        find_player(room, name, player_id) ||
        {:error, :not_found}
    end)
  end

  defp find_item(player, room, name) do
    case Game.find_item_in_inventories([player.inventory_id, room.inventory_id], name) do
      {:ok, [item | _]} ->
        contents =
          case Game.list_items_in_item(item) do
            {:ok, contents} -> contents
            {:error, :not_a_container} -> nil
          end

        {:ok, {:item, item, contents}}

      _ ->
        nil
    end
  end

  defp find_mob(room, name) do
    case Game.find_mob_in_room(room.id, name) do
      nil -> nil
      mob -> {:ok, {:mob, mob}}
    end
  end

  defp find_player(room, name, exclude_id) do
    case Game.find_player_in_room(room.id, name, exclude_id) do
      nil -> nil
      player -> {:ok, {:player, player}}
    end
  end

  defp format_contents(nil), do: ""
  defp format_contents([]), do: "\n<white>It is empty.</>"

  defp format_contents(items) do
    item_list =
      Enum.map_join(items, "\n", fn item ->
        "<gray>• </><green>#{item.name}</>"
      end)

    "\n<white>It contains:</>\n" <> item_list
  end
end
