defmodule Realms.Commands.Inventory do
  @moduledoc """
  Inventory command - lists the items the player is currently carrying.
  """

  @behaviour Realms.Commands.Command

  alias Realms.Game
  alias Realms.Messaging

  defstruct []

  @impl true
  def parse(input) when input in ["inventory", "inv", "i"], do: {:ok, %__MODULE__{}}
  def parse(_), do: :error

  @impl true
  def execute(%__MODULE__{}, context) do
    {:ok, %{player: player, items: items}} = fetch(context)

    Messaging.send_to_player(
      player.id,
      """
      <bright-yellow:b>Inventory</>
      <white>You are carrying:</>
      #{format_items_section(items)}
      """
    )

    :ok
  end

  @impl true
  def description, do: "List the items you are carrying"

  @impl true
  def examples, do: ["inventory", "inv", "i"]

  # Private helpers

  defp fetch(context) do
    Game.tx(fn ->
      player = Game.get_player!(context.player_id)
      items = Game.list_items_in_player(player)

      {:ok, %{player: player, items: items}}
    end)
  end

  defp format_items_section([]) do
    "<gray>Your hands are empty.</>\n"
  end

  defp format_items_section(items) do
    Enum.map_join(items, "\n", fn item ->
      "<gray>• </><bright-green>#{item.name}</>"
    end) <> "\n"
  end
end
