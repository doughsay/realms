defmodule Realms.MessagingTest do
  use ExUnit.Case, async: true

  alias Realms.Messaging
  alias Realms.Messaging.Message

  describe "send_to_player/2" do
    test "broadcasts message to player topic" do
      player_id = Ecto.UUID.generate()
      message = Message.new(:info, "Direct message")

      # Subscribe to player topic
      Messaging.subscribe_to_player(player_id)

      # Send message
      assert :ok = Messaging.send_to_player(player_id, message)

      # Verify we received it
      assert_receive {:game_message, ^message}
    end
  end

  describe "send_to_room/3" do
    test "broadcasts message to all subscribers in room" do
      room_id = Ecto.UUID.generate()
      message = Message.new(:say, "Hello, room!")

      # Subscribe to room
      Messaging.subscribe_to_room(room_id)

      # Send message
      assert :ok = Messaging.send_to_room(room_id, message)

      # Verify we received it
      assert_receive {:game_message, ^message}
    end

    test "broadcasts message to everyone except excluded process" do
      room_id = Ecto.UUID.generate()
      message = Message.new(:room_event, "Someone left")

      # Subscribe to room
      Messaging.subscribe_to_room(room_id)

      # Send message excluding self
      assert :ok = Messaging.send_to_room(room_id, message, exclude: self())

      # Verify we did NOT receive it (since we excluded ourselves)
      refute_receive {:game_message, ^message}, 100
    end

    test "broadcasts to multiple subscribers" do
      room_id = Ecto.UUID.generate()
      message = Message.new(:say, "Hello, everyone!")

      # Spawn another process that subscribes
      test_pid = self()

      other_process =
        spawn_link(fn ->
          Messaging.subscribe_to_room(room_id)
          send(test_pid, :subscribed)

          receive do
            {:game_message, msg} -> send(test_pid, {:other_received, msg})
          after
            1000 -> send(test_pid, :timeout)
          end
        end)

      # Wait for other process to subscribe
      assert_receive :subscribed

      # Subscribe ourselves
      Messaging.subscribe_to_room(room_id)

      # Send message
      Messaging.send_to_room(room_id, message)

      # Both processes should receive it
      assert_receive {:game_message, ^message}
      assert_receive {:other_received, ^message}

      # Clean up
      Process.unlink(other_process)
    end

    test "exclude option only excludes specified process" do
      room_id = Ecto.UUID.generate()
      message = Message.new(:room_event, "Event occurred")

      test_pid = self()

      # Spawn another process that subscribes
      other_process =
        spawn_link(fn ->
          Messaging.subscribe_to_room(room_id)
          send(test_pid, :subscribed)

          receive do
            {:game_message, msg} -> send(test_pid, {:other_received, msg})
          after
            1000 -> send(test_pid, :timeout)
          end
        end)

      # Wait for other process to subscribe
      assert_receive :subscribed

      # Subscribe ourselves
      Messaging.subscribe_to_room(room_id)

      # Send message excluding ourselves
      Messaging.send_to_room(room_id, message, exclude: self())

      # We should NOT receive it, but the other process should
      refute_receive {:game_message, ^message}, 100
      assert_receive {:other_received, ^message}

      # Clean up
      Process.unlink(other_process)
    end
  end

  describe "broadcast_global/1" do
    test "broadcasts message to global topic" do
      message = Message.new(:system, "Server maintenance")

      # Subscribe to global topic
      Phoenix.PubSub.subscribe(Realms.PubSub, "global")

      # Broadcast globally
      assert :ok = Messaging.broadcast_global(message)

      # Verify we received it
      assert_receive {:game_message, ^message}
    end
  end

  describe "subscribe_to_room/1" do
    test "subscribes current process to room topic" do
      room_id = Ecto.UUID.generate()

      assert :ok = Messaging.subscribe_to_room(room_id)

      # Send a message directly via PubSub to verify subscription
      message = Message.new(:info, "Test")
      Phoenix.PubSub.broadcast(Realms.PubSub, "room:#{room_id}", {:game_message, message})

      assert_receive {:game_message, ^message}
    end
  end

  describe "unsubscribe_from_room/1" do
    test "unsubscribes current process from room topic" do
      room_id = Ecto.UUID.generate()

      # Subscribe first
      Messaging.subscribe_to_room(room_id)

      # Unsubscribe
      assert :ok = Messaging.unsubscribe_from_room(room_id)

      # Send a message - we should NOT receive it
      message = Message.new(:info, "Test")
      Phoenix.PubSub.broadcast(Realms.PubSub, "room:#{room_id}", {:game_message, message})

      refute_receive {:game_message, ^message}, 100
    end
  end

  describe "subscribe_to_player/1" do
    test "subscribes current process to player topic" do
      player_id = Ecto.UUID.generate()

      assert :ok = Messaging.subscribe_to_player(player_id)

      # Send a message directly via PubSub to verify subscription
      message = Message.new(:info, "Whisper")
      Phoenix.PubSub.broadcast(Realms.PubSub, "player:#{player_id}", {:game_message, message})

      assert_receive {:game_message, ^message}
    end
  end

  describe "unsubscribe_from_player/1" do
    test "unsubscribes current process from player topic" do
      player_id = Ecto.UUID.generate()

      # Subscribe first
      Messaging.subscribe_to_player(player_id)

      # Unsubscribe
      assert :ok = Messaging.unsubscribe_from_player(player_id)

      # Send a message - we should NOT receive it
      message = Message.new(:info, "Test")
      Phoenix.PubSub.broadcast(Realms.PubSub, "player:#{player_id}", {:game_message, message})
      refute_receive {:game_message, ^message}, 100
    end
  end

  describe "subscribe_to_global/0" do
    test "subscribes current process to global topic" do
      assert :ok = Messaging.subscribe_to_global()
      # Send a message directly via PubSub to verify subscription
      message = Message.new(:info, "Whisper")
      Phoenix.PubSub.broadcast(Realms.PubSub, "global", {:game_message, message})

      assert_receive {:game_message, ^message}
    end
  end

  describe "unsubscribe_from_global/0" do
    test "unsubscribes current process from global topic" do
      # Subscribe first
      Messaging.subscribe_to_global()

      # Unsubscribe
      assert :ok = Messaging.unsubscribe_from_global()

      # Send a message - we should NOT receive it
      message = Message.new(:info, "Test")
      Phoenix.PubSub.broadcast(Realms.PubSub, "global", {:game_message, message})
      refute_receive {:game_message, ^message}, 100
    end
  end
end
