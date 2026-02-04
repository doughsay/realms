defmodule Realms.Commands.Banner do
  @moduledoc """
  Banner command - displays the game banner.
  """

  @behaviour Realms.Commands.Command

  alias Realms.Messaging
  alias Realms.Messaging.Banner

  defstruct []

  @impl true
  def parse("banner"), do: {:ok, %__MODULE__{}}
  def parse(_), do: :error

  @impl true
  def execute(%__MODULE__{}, context) do
    banner = Banner.banner()
    Messaging.send_to_player(context.player_id, banner)

    :ok
  end

  @impl true
  def description, do: "Show game banner"

  @impl true
  def examples, do: ["banner"]
end
