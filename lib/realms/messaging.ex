defmodule Realms.Messaging do
  @moduledoc """
  Public API for game messaging and broadcasting.

  This module provides the public API for sending messages to players and rooms,
  and managing subscriptions. It encapsulates all PubSub logic and provides the
  foundation for game communication.
  """

  alias Realms.Messaging.Message

  @pubsub Realms.PubSub

  # Public API

  @doc """
  Send a message directly to a specific player.

  ## Examples

      iex> message = Message.new(:info, "You receive a whisper")
      iex> Messaging.send_to_player(player_id, message)
      :ok
  """
  def send_to_player(player_id, %Message{} = message) do
    Phoenix.PubSub.broadcast(@pubsub, player_topic(player_id), {:game_message, message})
  end

  @doc """
  Send a message to all players in a room.

  ## Options

    * `:exclude` - PID of a process to exclude from the broadcast (typically self())

  ## Examples

      # Broadcast to everyone in the room
      iex> message = Message.new(:say, "Hello, world!")
      iex> Messaging.send_to_room(room_id, message)
      :ok

      # Broadcast to everyone except the sender
      iex> message = Message.new(:room_event, "Player arrived")
      iex> Messaging.send_to_room(room_id, message, exclude: self())
      :ok
  """
  def send_to_room(room_id, %Message{} = message, opts \\ []) do
    topic = room_topic(room_id)
    wrapped_message = {:game_message, message}

    case Keyword.get(opts, :exclude) do
      nil ->
        Phoenix.PubSub.broadcast(@pubsub, topic, wrapped_message)

      pid when is_pid(pid) ->
        Phoenix.PubSub.broadcast_from(@pubsub, pid, topic, wrapped_message)
    end
  end

  @doc """
  Broadcast a message to all connected players globally.

  ## Examples

      iex> message = Message.new(:system, "Server maintenance in 5 minutes")
      iex> Messaging.broadcast_global(message)
      :ok
  """
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
