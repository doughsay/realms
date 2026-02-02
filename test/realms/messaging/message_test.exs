defmodule Realms.Messaging.MessageTest do
  use ExUnit.Case, async: true

  alias Realms.Messaging.Message

  describe "new/2" do
    test "creates message with generated ID and current timestamp" do
      message = Message.new(:info, "Test message")

      assert %Message{} = message
      assert message.type == :info
      assert message.content == "Test message"
      assert is_binary(message.id)
      assert %DateTime{} = message.timestamp
      assert DateTime.diff(DateTime.utc_now(), message.timestamp, :second) == 0
    end

    test "generates unique IDs for different messages" do
      message1 = Message.new(:info, "First")
      message2 = Message.new(:info, "Second")

      assert message1.id != message2.id
    end

    test "supports all message types" do
      types = [:room, :say, :room_event, :error, :info, :players, :command_echo, :system]

      for type <- types do
        message = Message.new(type, "Content")
        assert message.type == type
      end
    end
  end
end
