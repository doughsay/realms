defmodule Realms.Commands.GetFrom do
  @moduledoc """
  GetFrom command - picks up an item from a container.
  """
  @behaviour Realms.Commands.Command

  alias Realms.Commands.Command
  alias Realms.Game
  alias Realms.Messaging

  defstruct [:item_name, :container_name]

  @impl Command
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

  @impl Command
  def execute(%__MODULE__{item_name: item_name, container_name: container_name}, context) do
    case get_from_container(context.player_id, item_name, container_name) do
      {:ok, %{player: player, item: item, container: container}} ->
        Messaging.send_to_player(
          player.id,
          "<green>You take #{item.name} from #{container.name}.</>"
        )

        Messaging.send_to_room(
          player.current_room_id,
          "<yellow>#{player.name}</> takes something from <cyan>#{container.name}</>.",
          exclude: player.id
        )

      {:error, :container_not_found} ->
        Messaging.send_to_player(
          context.player_id,
          "<red>You're not holding '#{container_name}'.</>"
        )

      {:error, {:item_not_found, container}} ->
        Messaging.send_to_player(
          context.player_id,
          "<red>You don't see '#{item_name}' in the #{container.name}.</>"
        )
    end

    :ok
  end

  @impl Command
  def description, do: "Get an item from a container"

  @impl Command
  def examples, do: ["get apple from backpack"]

  # Private helpers

  defp get_from_container(player_id, item_name, container_name) do
    Game.tx(fn ->
      player = Game.get_player!(player_id)

      with {:ok, container} <- find_held_container(player.inventory_id, container_name),
           {:ok, item} <- find_item_in_container(container, item_name) do
        {:ok, _} = Game.move_item_to_player(item, player)
        {:ok, %{player: player, item: item, container: container}}
      end
    end)
  end

  defp find_held_container(inventory_id, name) do
    case Game.find_item_in_inventory(inventory_id, name) do
      {:error, _} -> {:error, :container_not_found}
      {:ok, container} -> {:ok, container}
    end
  end

  defp find_item_in_container(container, name) do
    with {:ok, inventory_id} <- Game.fetch_container_inventory_id(container),
         {:ok, item} <- Game.find_item_in_inventory(inventory_id, name) do
      {:ok, item}
    else
      _ -> {:error, {:item_not_found, container}}
    end
  end
end
