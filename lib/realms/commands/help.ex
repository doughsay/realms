defmodule Realms.Commands.Help do
  @moduledoc """
  Help command - shows available commands.
  """

  @behaviour Realms.Commands.Command

  alias Realms.Messaging

  defstruct []

  @impl true
  def parse("help"), do: {:ok, %__MODULE__{}}
  def parse(_), do: :error

  @impl true
  def execute(%__MODULE__{}, context) do
    Messaging.send_to_player(
      context.player_id,
      """
      <bright-yellow:b>Available Commands</>
      <cyan:b>Movement:</> north, south, east, west, northeast, northwest, southeast, southwest, up, down, in, out
      <cyan:b>say \\<message>:</> Chat with players in the same room
      <cyan:b>look:</> Show current room description
      <cyan:b>exits:</> List available exits
      <cyan:b>help:</> Show this message
      """
    )

    :ok
  end

  @impl true
  def description, do: "Show available commands"

  @impl true
  def examples, do: ["help"]
end
