defmodule Realms.Commands.Say do
  @moduledoc """
  Say command - broadcasts a message to all players in the current room.
  """

  @behaviour Realms.Commands.Command

  alias Realms.Game
  alias Realms.Messaging
  alias Realms.Messaging.MessageBuilder

  defstruct [:message]

  @impl true
  def parse("say" <> message_text) do
    {:ok, %__MODULE__{message: String.trim(message_text)}}
  end

  def parse(_), do: :error

  @impl true
  def execute(%__MODULE__{message: ""}, context) do
    msg = MessageBuilder.simple("Say what?", :red, [:bold])
    Messaging.send_to_player(context.player_id, msg)
    :ok
  end

  def execute(%__MODULE__{message: message_text}, context) do
    player = Game.get_player!(context.player_id)

    # Message to others in the room
    message =
      MessageBuilder.new()
      |> MessageBuilder.text(player.name, :bright_cyan)
      |> MessageBuilder.text(" says: ", :gray)
      |> MessageBuilder.text(message_text, :white)
      |> MessageBuilder.build()

    Messaging.send_to_room(player.current_room_id, message, exclude: context.player_id)

    # Message to the speaker
    message =
      MessageBuilder.new()
      |> MessageBuilder.text("You say: ", :gray)
      |> MessageBuilder.text(message_text, :white)
      |> MessageBuilder.build()

    Messaging.send_to_player(context.player_id, message)

    :ok
  end

  @impl true
  def description, do: "Chat with players in the same room"

  @impl true
  def examples, do: ["say hello", "say How's everyone doing?"]
end
