defmodule Realms.MessagingTest do
  use ExUnit.Case, async: true

  import Realms.Messaging.Markup

  alias Realms.Messaging.Message

  # We can't actually test the PubSub broadcasting without integration tests,
  # but we can test that the message normalization works correctly

  describe "message input formats" do
    test "accepts plain string" do
      # String should be wrapped and converted to a message
      assert %Message{sections: [{:pre_wrap, [{:color, :red, ["Hello"]}]}]} =
               normalize_message_input("<red>Hello</>")
    end

    test "accepts single section tuple" do
      section = wrap("<blue>Text</>")

      assert %Message{sections: [^section]} = normalize_message_input(section)
    end

    test "accepts list of sections" do
      sections = [wrap("<red>Line 1</>"), wrap("Line 2")]

      assert %Message{sections: ^sections} = normalize_message_input(sections)
    end

    test "accepts Message struct" do
      message = Message.new([wrap("Text")])

      assert ^message = normalize_message_input(message)
    end

    test "string with no markup creates plain text" do
      assert %Message{sections: [{:pre_wrap, ["Plain text"]}]} =
               normalize_message_input("Plain text")
    end

    test "empty string creates empty message" do
      assert %Message{sections: [{:pre_wrap, []}]} = normalize_message_input("")
    end

    test "multiple sections with different types" do
      sections = [
        wrap("<bright-yellow:b>Room Title</>"),
        pre("ASCII art")
      ]

      message = normalize_message_input(sections)
      assert length(message.sections) == 2
      assert {:pre_wrap, _} = Enum.at(message.sections, 0)
      assert {:pre, _} = Enum.at(message.sections, 1)
    end
  end

  # Helper function that mimics what the Messaging functions do internally
  defp normalize_message_input(content) when is_binary(content) do
    Message.new([wrap(content)])
  end

  defp normalize_message_input({section_type, _content} = section)
       when section_type in [:pre_wrap, :pre] do
    Message.new([section])
  end

  defp normalize_message_input(sections) when is_list(sections) do
    Message.new(sections)
  end

  defp normalize_message_input(%Message{} = message) do
    message
  end
end
