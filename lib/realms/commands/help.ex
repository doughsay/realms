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
      <cyan:b>tell \\<target> \\<message>:</> Send private message to online player
      <cyan:b>look:</> Show current room description
      <cyan:b>inventory:</> List items you are carrying (alias: inv, i)
      <cyan:b>get \\<item>:</> Pick up an item from the room
      <cyan:b>get \\<item> from \\<container>:</> Take an item out of a container
      <cyan:b>drop \\<item>:</> Drop an item
      <cyan:b>put \\<item> in \\<container>:</> Put an item into a container
      <cyan:b>examine \\<item>:</> Examine an item (alias: x)
      <cyan:b>exits:</> List available exits
      <cyan:b>banner:</> Show game banner
      <cyan:b>clear:</> Clear your message history
      <cyan:b>crash:</> Intentionally crash (for testing)
      <cyan:b>hang:</> Intentionally hang forever (for testing)
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
