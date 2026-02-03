defmodule Realms.Messaging.MessageBuilderTest do
  use ExUnit.Case, async: true

  alias Realms.Messaging.Message
  alias Realms.Messaging.MessageBuilder

  describe "markup/2" do
    test "adds markup segments to builder" do
      message =
        MessageBuilder.new()
        |> MessageBuilder.markup("{red}Hello{/} {blue}world{/}")
        |> MessageBuilder.build()

      assert %Message{segments: segments} = message

      assert segments == [
               %{text: "Hello", color: :red, modifiers: []},
               %{text: " ", color: :white, modifiers: []},
               %{text: "world", color: :blue, modifiers: []}
             ]
    end

    test "combines with regular builder methods" do
      message =
        MessageBuilder.new()
        |> MessageBuilder.text("Start ", :white)
        |> MessageBuilder.markup("{red:b}middle{/}")
        |> MessageBuilder.text(" end", :white)
        |> MessageBuilder.build()

      assert %Message{segments: segments} = message

      assert segments == [
               %{text: "Start ", color: :white, modifiers: []},
               %{text: "middle", color: :red, modifiers: [:bold]},
               %{text: " end", color: :white, modifiers: []}
             ]
    end

    test "falls back to plain text on parse error" do
      message =
        MessageBuilder.new()
        |> MessageBuilder.markup("{invalid")
        |> MessageBuilder.build()

      assert %Message{segments: segments} = message

      assert segments == [
               %{text: "{invalid", color: :white, modifiers: []}
             ]
    end
  end

  describe "from_markup/1" do
    test "creates message directly from markup" do
      message = MessageBuilder.from_markup("{bright-yellow:b}Title{/}")

      assert %Message{segments: segments} = message

      assert segments == [
               %{text: "Title", color: :bright_yellow, modifiers: [:bold]}
             ]
    end

    test "handles complex markup" do
      message =
        MessageBuilder.from_markup("{gray}Exits:{/} {bright-cyan}north, south{/}")

      assert %Message{segments: segments} = message

      assert segments == [
               %{text: "Exits:", color: :gray, modifiers: []},
               %{text: " ", color: :white, modifiers: []},
               %{text: "north, south", color: :bright_cyan, modifiers: []}
             ]
    end

    test "falls back to plain text on parse error" do
      message = MessageBuilder.from_markup("{unclosed")

      assert %Message{segments: segments} = message

      assert segments == [
               %{text: "{unclosed", color: :white, modifiers: []}
             ]
    end

    test "handles empty string" do
      message = MessageBuilder.from_markup("")

      assert %Message{segments: segments} = message
      assert segments == []
    end
  end

  describe "integration examples" do
    test "room description with markup" do
      message =
        MessageBuilder.from_markup("""
        {bright-yellow:b}The Throne Room{/}
        A magnificent hall with {amber}golden{/} pillars.
        """)

      assert %Message{segments: segments} = message

      assert segments == [
               %{text: "The Throne Room", color: :bright_yellow, modifiers: [:bold]},
               %{text: "\nA magnificent hall with ", color: :white, modifiers: []},
               %{text: "golden", color: :amber, modifiers: []},
               %{text: " pillars.\n", color: :white, modifiers: []}
             ]
    end

    test "mixed builder and markup approach" do
      player_name = "Alice"

      message =
        MessageBuilder.new()
        |> MessageBuilder.markup("{bright-green}#{player_name}{/} has")
        |> MessageBuilder.text(" arrived!", :white)
        |> MessageBuilder.build()

      assert %Message{segments: segments} = message

      assert segments == [
               %{text: "Alice", color: :bright_green, modifiers: []},
               %{text: " has", color: :white, modifiers: []},
               %{text: " arrived!", color: :white, modifiers: []}
             ]
    end
  end
end
