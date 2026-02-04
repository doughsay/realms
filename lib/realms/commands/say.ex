defmodule Realms.Commands.Say do
  @moduledoc """
  Say command - broadcasts a message to all players in the current room.
  """

  @behaviour Realms.Commands.Command

  alias Realms.Game
  alias Realms.Messaging

  defstruct [:message]

  @impl true
  def parse("say" <> message_text) do
    {:ok, %__MODULE__{message: String.trim(message_text)}}
  end

  def parse(_), do: :error

  @impl true
  def execute(%__MODULE__{message: ""}, context) do
    Messaging.send_to_player(context.player_id, "<red>Say what?</>")
    :ok
  end

  def execute(%__MODULE__{message: message_text}, context) do
    player = Game.get_player!(context.player_id)

    # Message to others in the room
    Messaging.send_to_room(
      player.current_room_id,
      "<bright-cyan>#{player.name}</><gray> says: </><white>#{message_text}</>",
      exclude: context.player_id
    )

    # Message to the speaker
    Messaging.send_to_player(context.player_id, "<gray>You say: </><white>#{message_text}</>")

    :ok
  end

  @impl true
  def description, do: "Chat with players in the same room"

  @impl true
  def examples, do: ["say hello", "say How's everyone doing?"]
end
