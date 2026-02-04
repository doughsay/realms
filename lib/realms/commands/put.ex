defmodule Realms.Commands.Put do
  @moduledoc """
  Put command - puts an item into a container.
  """
  @behaviour Realms.Commands.Command

  alias Realms.Commands.Utils
  alias Realms.Game
  alias Realms.Messaging

  defstruct [:item_name, :container_name]

  @impl true
  def parse("put " <> rest) do
    parts = String.split(rest, ~r/\s+into\s+|\s+in\s+/, parts: 2)

    case parts do
      [item_name, container_name] ->
        item_name = String.trim(item_name)
        container_name = String.trim(container_name)

        if item_name != "" and container_name != "" do
          {:ok, %__MODULE__{item_name: item_name, container_name: container_name}}
        else
          :error
        end

      _ ->
        :error
    end
  end

  def parse(_), do: :error

  @impl true
  def execute(%__MODULE__{item_name: item_name, container_name: container_name}, context) do
    player = Game.get_player!(context.player_id)
    inventory_items = Game.list_items_in_player(player)

    case Utils.match_item(inventory_items, item_name) do
      nil ->
        Messaging.send_to_player(player.id, "<red>You aren't holding '#{item_name}'.</>")

      item ->
        case Utils.match_item(inventory_items, container_name) do
          nil ->
            Messaging.send_to_player(player.id, "<red>You aren't holding '#{container_name}'.</>")

          container ->
            if item.id == container.id do
              Messaging.send_to_player(player.id, "<red>You can't put an item inside itself.</>")
            else
              case Game.move_item_to_item(item, container) do
                {:ok, _} ->
                  Messaging.send_to_player(
                    player.id,
                    "<green>You put #{item.name} into #{container.name}.</>"
                  )

                  Messaging.send_to_room(
                    player.current_room_id,
                    "<yellow>#{player.name}</> puts something into <cyan>#{container.name}</>.",
                    exclude: player.id
                  )

                {:error, :no_inventory} ->
                  Messaging.send_to_player(player.id, "<red>That doesn't seem to hold things.</>")

                {:error, _} ->
                  Messaging.send_to_player(player.id, "<red>You can't do that.</>")
              end
            end
        end
    end

    :ok
  end

  @impl true
  def description, do: "Put an item into a container"

  @impl true
  def examples, do: ["put apple in backpack", "put sword into chest"]
end
