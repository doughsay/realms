defmodule Realms.Messaging.MessageTest do
  use ExUnit.Case, async: true

  alias Realms.Messaging.Message

  describe "new/1" do
    test "creates a message with segments" do
      segments = [
        %{text: "Hello", color: :red, modifiers: []},
        %{text: " world", color: :white, modifiers: []}
      ]

      message = Message.new(segments)

      assert %Message{} = message
      assert message.segments == segments
      assert message.id
      assert message.timestamp
    end

    test "normalizes plain text segments" do
      message = Message.new(["hello", "world"])

      assert message.segments == [
               %{text: "hello", color: :white, modifiers: []},
               %{text: "world", color: :white, modifiers: []}
             ]
    end

    test "normalizes segments with missing modifiers" do
      message = Message.new([%{text: "hello", color: :red}])

      assert message.segments == [
               %{text: "hello", color: :red, modifiers: []}
             ]
    end
  end

  describe "from_markup/1" do
    test "creates message from simple markup" do
      message = Message.from_markup("{red}Hello{/}")

      assert %Message{} = message

      assert message.segments == [
               %{text: "Hello", color: :red, modifiers: []}
             ]
    end

    test "creates message from complex markup" do
      message = Message.from_markup("{bright-yellow:b}Title{/} with {i}style{/}")

      assert message.segments == [
               %{text: "Title", color: :bright_yellow, modifiers: [:bold]},
               %{text: " with ", color: :white, modifiers: []},
               %{text: "style", color: :white, modifiers: [:italic]}
             ]
    end

    test "falls back to plain text on parse error" do
      message = Message.from_markup("{unclosed")

      assert message.segments == [
               %{text: "{unclosed", color: :white, modifiers: []}
             ]
    end

    test "handles empty string" do
      message = Message.from_markup("")

      assert message.segments == []
    end
  end

  describe "sigil_m/2" do
    import Realms.Messaging.Message

    test "creates message from markup" do
      message = ~m"{green}Success{/}"

      assert message.segments == [
               %{text: "Success", color: :green, modifiers: []}
             ]
    end

    test "supports interpolation" do
      name = "World"
      message = ~m"{blue}Hello #{name}{/}"

      assert message.segments == [
               %{text: "Hello World", color: :blue, modifiers: []}
             ]
    end
  end
end
