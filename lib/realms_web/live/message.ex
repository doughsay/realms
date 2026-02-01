defmodule RealmsWeb.Message do
  @moduledoc """
  Represents a message in the game (chat, room events, errors, etc.)
  """

  @enforce_keys [:id, :type, :content, :timestamp]
  defstruct [:id, :type, :content, :timestamp]

  @type message_type :: :room | :say | :room_event | :error | :info | :players | :command_echo
  @type t :: %__MODULE__{
          id: String.t(),
          type: message_type(),
          content: String.t(),
          timestamp: DateTime.t()
        }

  @doc """
  Create a new message with a generated ID and current timestamp.
  Used for local messages (errors, room descriptions, etc.)
  """
  def new(type, content) do
    %__MODULE__{
      id: Ecto.UUID.generate(),
      type: type,
      content: content,
      timestamp: DateTime.utc_now()
    }
  end

  @doc """
  Create a new message with pre-generated ID and timestamp.
  Used for PubSub messages to ensure consistency across multiple tabs.
  """
  def new(type, content, id, timestamp) do
    %__MODULE__{
      id: id,
      type: type,
      content: content,
      timestamp: timestamp
    }
  end
end
