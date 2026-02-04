defmodule Realms.Commands.Clear do
  @moduledoc """
  Clear command - clears the player's message history.
  """

  @behaviour Realms.Commands.Command

  alias Realms.PlayerServer

  defstruct []

  @impl true
  def parse("clear"), do: {:ok, %__MODULE__{}}
  def parse(_), do: :error

  @impl true
  def execute(%__MODULE__{}, context) do
    PlayerServer.clear_history(context.player_id)
    :ok
  end

  @impl true
  def description, do: "Clear your message history"

  @impl true
  def examples, do: ["clear"]
end
