defmodule Realms.Commands.Put do
  @moduledoc """
  Put command - puts an item into a container.
  """

  @behaviour Realms.Commands.Command

  alias Realms.Commands.Command
  alias Realms.Game
  alias Realms.Messaging

  defstruct [:item_name, :container_name]

  @impl Command
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

  @impl Command
  def execute(%__MODULE__{item_name: item_name, container_name: container_name}, context) do
    case put_in_container(context.player_id, item_name, container_name) do
      {:ok, %{player: player, item: item, container: container}} ->
        Messaging.send_to_player(
          player.id,
          "<green>You put #{item.name} into #{container.name}.</>"
        )

        Messaging.send_to_room(
          player.current_room_id,
          "<yellow>#{player.name}</> puts <cyan>#{item.name}</> into <cyan>#{container.name}</>.",
          exclude: player.id
        )

      {:error, :item_not_found} ->
        Messaging.send_to_player(context.player_id, "<red>You aren't holding '#{item_name}'.</>")

      {:error, :item_ambiguous} ->
        Messaging.send_to_player(
          context.player_id,
          "<red>Multiple items match '#{item_name}'. Be more specific.</>"
        )

      {:error, :container_not_found} ->
        Messaging.send_to_player(
          context.player_id,
          "<red>You aren't holding '#{container_name}'.</>"
        )

      {:error, :container_ambiguous} ->
        Messaging.send_to_player(
          context.player_id,
          "<red>Multiple items match '#{container_name}'. Be more specific.</>"
        )

      {:error, :self_containment} ->
        Messaging.send_to_player(
          context.player_id,
          "<red>You can't put an item inside itself.</>"
        )

      {:error, :not_a_container} ->
        Messaging.send_to_player(context.player_id, "<red>That doesn't seem to hold things.</>")
    end

    :ok
  end

  @impl Command
  def description, do: "Put an item into a container"

  @impl Command
  def examples, do: ["put apple in backpack", "put sword into chest"]

  # Private helpers

  defp put_in_container(player_id, item_name, container_name) do
    Game.tx(fn ->
      player = Game.get_player!(player_id)

      with {:ok, item} <- find_item(player.inventory_id, item_name),
           {:ok, container} <- find_container(player.inventory_id, container_name),
           :ok <- check_distinct(item, container),
           :ok <- check_is_container(container),
           {:ok, _} <- Game.move_item_to_item(item, container) do
        {:ok, %{player: player, item: item, container: container}}
      end
    end)
  end

  defp find_item(inventory_id, name) do
    case Game.find_item_in_inventory(inventory_id, name) do
      {:ok, item} -> {:ok, item}
      {:error, :no_matching_item} -> {:error, :item_not_found}
      {:error, :ambiguous} -> {:error, :item_ambiguous}
    end
  end

  defp find_container(inventory_id, name) do
    case Game.find_item_in_inventory(inventory_id, name) do
      {:ok, item} -> {:ok, item}
      {:error, :no_matching_item} -> {:error, :container_not_found}
      {:error, :ambiguous} -> {:error, :container_ambiguous}
    end
  end

  defp check_distinct(item, container) do
    if item.id == container.id, do: {:error, :self_containment}, else: :ok
  end

  defp check_is_container(container) do
    if Game.get_container_inventory_id(container), do: :ok, else: {:error, :not_a_container}
  end
end
