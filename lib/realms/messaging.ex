defmodule Realms.Messaging do
  @moduledoc """
  Public API for game messaging and broadcasting.

  This module provides the public API for sending messages to players and rooms,
  and managing subscriptions. It encapsulates all PubSub logic and provides the
  foundation for game communication.

  ## Message Input Formats

  All messaging functions accept multiple input formats for convenience:

  - **String**: Automatically parsed with `Markup.wrap/1`
    ```elixir
    send_to_player(player_id, "<blue>Hello world!</>")
    ```

  - **Single section**: A section tuple
    ```elixir
    send_to_player(player_id, wrap("<title>Title</>"))
    ```

  - **List of sections**: Multiple sections
    ```elixir
    send_to_player(player_id, [
      wrap("<title>Title</>"),
      pre("ASCII art")
    ])
    ```

  - **Message struct**: Full message (backward compatibility)
    ```elixir
    send_to_player(player_id, Message.new([...]))
    ```
  """

  import Realms.Messaging.Markup

  alias Realms.Messaging.Message
  alias Realms.PlayerServer

  @pubsub Realms.PubSub

  # Public API

  @doc """
  Send a message directly to a specific player.

  Accepts a string (parsed with markup), a section tuple, a list of sections,
  or a Message struct.

  ## Examples

      # Simple string with markup
      iex> Messaging.send_to_player(player_id, "<blue>Hello!</>")
      :ok

      # Single section
      iex> Messaging.send_to_player(player_id, wrap("<title>Title</>"))
      :ok

      # Multiple sections
      iex> Messaging.send_to_player(player_id, [wrap("Text"), pre("Art")])
      :ok

      # Full message struct
      iex> message = Message.new([wrap("Text")])
      iex> Messaging.send_to_player(player_id, message)
      :ok
  """
  def send_to_player(player_id, content) when is_binary(content) do
    send_to_player(player_id, Message.new([wrap(content)]))
  end

  def send_to_player(player_id, {section_type, _content} = section)
      when section_type in [:pre_wrap, :pre] do
    send_to_player(player_id, Message.new([section]))
  end

  def send_to_player(player_id, sections) when is_list(sections) do
    send_to_player(player_id, Message.new(sections))
  end

  def send_to_player(player_id, %Message{} = message) do
    Phoenix.PubSub.broadcast(@pubsub, player_topic(player_id), {:game_message, message})
  end

  @doc """
  Send a message to all players in a room.

  Accepts a string (parsed with markup), a section tuple, a list of sections,
  or a Message struct.

  ## Options

    * `:exclude` - PID of a process to exclude from the broadcast (typically
      self()), or a player_id to exclude that player's process (if connected).

  ## Examples

      # Simple string
      iex> Messaging.send_to_room(room_id, "<yellow>The door creaks open.</>")
      :ok

      # With exclusion
      iex> Messaging.send_to_room(room_id, "Player arrived", exclude: self())
      :ok

      # Multiple sections
      iex> Messaging.send_to_room(room_id, [wrap("Text"), pre("Map")])
      :ok

      # Full message struct
      iex> message = Message.new([wrap("Text")])
      iex> Messaging.send_to_room(room_id, message, exclude: self())
      :ok
  """
  def send_to_room(room_id, content, opts \\ [])

  def send_to_room(room_id, content, opts) when is_binary(content) do
    send_to_room(room_id, Message.new([wrap(content)]), opts)
  end

  def send_to_room(room_id, {section_type, _content} = section, opts)
      when section_type in [:pre_wrap, :pre] do
    send_to_room(room_id, Message.new([section]), opts)
  end

  def send_to_room(room_id, sections, opts) when is_list(sections) do
    if Keyword.keyword?(sections) do
      raise ArgumentError, "Expected a Message, string, section, or list of sections"
    else
      send_to_room(room_id, Message.new(sections), opts)
    end
  end

  def send_to_room(room_id, %Message{} = message, opts) do
    topic = room_topic(room_id)
    wrapped_message = {:game_message, message}

    case Keyword.get(opts, :exclude) do
      nil ->
        Phoenix.PubSub.broadcast(@pubsub, topic, wrapped_message)

      pid when is_pid(pid) ->
        Phoenix.PubSub.broadcast_from(@pubsub, pid, topic, wrapped_message)

      player_id when is_binary(player_id) ->
        case PlayerServer.whereis?(player_id) do
          {:ok, pid} -> Phoenix.PubSub.broadcast_from(@pubsub, pid, topic, wrapped_message)
          :error -> Phoenix.PubSub.broadcast(@pubsub, topic, wrapped_message)
        end
    end
  end

  @doc """
  Broadcast a message to all connected players globally.

  Accepts a string (parsed with markup), a section tuple, a list of sections,
  or a Message struct.

  ## Examples

      # Simple string
      iex> Messaging.broadcast_global("<red:b>Server maintenance in 5 minutes</>")
      :ok

      # Multiple sections
      iex> Messaging.broadcast_global([wrap("Title"), wrap("Details")])
      :ok

      # Full message struct
      iex> message = Message.new([wrap("System message")])
      iex> Messaging.broadcast_global(message)
      :ok
  """
  def broadcast_global(content) when is_binary(content) do
    broadcast_global(Message.new([wrap(content)]))
  end

  def broadcast_global({section_type, _content} = section)
      when section_type in [:pre_wrap, :pre] do
    broadcast_global(Message.new([section]))
  end

  def broadcast_global(sections) when is_list(sections) do
    broadcast_global(Message.new(sections))
  end

  def broadcast_global(%Message{} = message) do
    Phoenix.PubSub.broadcast(@pubsub, global_topic(), {:game_message, message})
  end

  @doc """
  Subscribe the current process to a room's message stream.

  ## Examples

      iex> Messaging.subscribe_to_room(room_id)
      :ok
  """
  def subscribe_to_room(room_id) do
    Phoenix.PubSub.subscribe(@pubsub, room_topic(room_id))
  end

  @doc """
  Unsubscribe the current process from a room's message stream.

  ## Examples

      iex> Messaging.unsubscribe_from_room(room_id)
      :ok
  """
  def unsubscribe_from_room(room_id) do
    Phoenix.PubSub.unsubscribe(@pubsub, room_topic(room_id))
  end

  @doc """
  Subscribe the current process to a player's direct message stream.

  ## Examples

      iex> Messaging.subscribe_to_player(player_id)
      :ok
  """
  def subscribe_to_player(player_id) do
    Phoenix.PubSub.subscribe(@pubsub, player_topic(player_id))
  end

  @doc """
  Unsubscribe the current process from a player's direct message stream.

  ## Examples

      iex> Messaging.unsubscribe_from_player(player_id)
      :ok
  """
  def unsubscribe_from_player(player_id) do
    Phoenix.PubSub.unsubscribe(@pubsub, player_topic(player_id))
  end

  @doc """
  Subscribe the current process to global messages.

  ## Examples

      iex> Messaging.subscribe_to_global()
      :ok
  """
  def subscribe_to_global do
    Phoenix.PubSub.subscribe(@pubsub, global_topic())
  end

  @doc """
  Unsubscribe the current process from global messages.

  ## Examples

      iex> Messaging.unsubscribe_from_global()
      :ok
  """
  def unsubscribe_from_global do
    Phoenix.PubSub.unsubscribe(@pubsub, global_topic())
  end

  # Private

  defp room_topic(room_id), do: "room:#{room_id}"

  defp player_topic(player_id), do: "player:#{player_id}"

  defp global_topic, do: "global"
end
