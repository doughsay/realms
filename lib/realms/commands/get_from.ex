defmodule Realms.Commands.GetFrom do
  @moduledoc """
  GetFrom command - picks up an item from a container.
  """
  @behaviour Realms.Commands.Command

  alias Realms.Commands.Utils
  alias Realms.Game
  alias Realms.Messaging

  defstruct [:item_name, :container_name]

  @impl true

  def parse("get " <> rest) do
    case String.split(rest, " from ", parts: 2) do
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

    case Utils.match_item(inventory_items, container_name) do
      nil ->
        Messaging.send_to_player(player.id, "<red>You're not holding '#{container_name}'.</>")

      container ->
        container_items = Game.list_items_in_item(container)

        case Utils.match_item(container_items, item_name) do
          nil ->
            Messaging.send_to_player(
              player.id,
              "<red>You don't see '#{item_name}' in the #{container.name}.</>"
            )

          item ->
            case Game.move_item_to_player(item, player) do
              {:ok, _} ->
                Messaging.send_to_player(
                  player.id,
                  "<green>You take #{item.name} from #{container.name}.</>"
                )

                Messaging.send_to_room(
                  player.current_room_id,
                  "<yellow>#{player.name}</> takes something from <cyan>#{container.name}</>.",
                  exclude: player.id
                )

              {:error, _} ->
                Messaging.send_to_player(player.id, "<red>You can't take that.</>")
            end
        end
    end

    :ok
  end

  @impl true

  def description, do: "Get an item from a container"

  @impl true

  def examples, do: ["get apple from backpack"]
end
