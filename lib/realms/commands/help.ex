defmodule Realms.Commands.Help do
  @moduledoc """
  Help command - shows available commands.
  """

  @behaviour Realms.Commands.Command

  alias Realms.Messaging
  alias Realms.Messaging.Message

  defstruct []

  @impl true
  def parse("help"), do: {:ok, %__MODULE__{}}
  def parse(_), do: :error

  @impl true
  def execute(%__MODULE__{}, context) do
    help_text = """
    Available commands:
    - Movement: north, south, east, west, northeast, northwest, southeast, southwest, up, down, in, out
    - say <message>: Chat with players in the same room
    - look: Show current room description
    - exits: List available exits
    - help: Show this message
    """

    message = Message.new(:info, help_text)
    Messaging.send_to_player(context.player_id, message)

    :ok
  end

  @impl true
  def description, do: "Show available commands"

  @impl true
  def examples, do: ["help"]
end
