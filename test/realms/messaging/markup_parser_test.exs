defmodule Realms.Messaging.MarkupParserTest do
  use ExUnit.Case, async: true

  alias Realms.Messaging.MarkupParser
  alias Realms.Messaging.Message

  describe "parse/1" do
    test "returns a Message struct" do
      assert {:ok, %Message{}} = MarkupParser.parse("hello")
    end

    test "parses plain text as white with no modifiers" do
      assert {:ok, message} = MarkupParser.parse("hello world")
      assert message.segments == [%{text: "hello world", color: :white, modifiers: []}]
    end

    test "parses empty string" do
      assert {:ok, message} = MarkupParser.parse("")
      assert message.segments == []
    end
  end

  describe "basic colors" do
    test "parses simple red text" do
      assert {:ok, segments} = MarkupParser.parse_segments("{red}danger{/}")

      assert segments == [
               %{text: "danger", color: :red, modifiers: []}
             ]
    end

    test "parses bright yellow text" do
      assert {:ok, segments} = MarkupParser.parse_segments("{bright-yellow}warning{/}")

      assert segments == [
               %{text: "warning", color: :bright_yellow, modifiers: []}
             ]
    end

    test "parses gray-light text" do
      assert {:ok, segments} = MarkupParser.parse_segments("{gray-light}subtle{/}")

      assert segments == [
               %{text: "subtle", color: :gray_light, modifiers: []}
             ]
    end

    test "parses multiple colored segments" do
      assert {:ok, segments} = MarkupParser.parse_segments("{red}red{/} {blue}blue{/}")

      assert segments == [
               %{text: "red", color: :red, modifiers: []},
               %{text: " ", color: :white, modifiers: []},
               %{text: "blue", color: :blue, modifiers: []}
             ]
    end

    test "parses mixed plain and colored text" do
      assert {:ok, segments} =
               MarkupParser.parse_segments("Normal {red}colored{/} normal again")

      assert segments == [
               %{text: "Normal ", color: :white, modifiers: []},
               %{text: "colored", color: :red, modifiers: []},
               %{text: " normal again", color: :white, modifiers: []}
             ]
    end
  end

  describe "modifiers" do
    test "parses bold text" do
      assert {:ok, segments} = MarkupParser.parse_segments("{b}bold{/}")

      assert segments == [
               %{text: "bold", color: :white, modifiers: [:bold]}
             ]
    end

    test "parses italic text" do
      assert {:ok, segments} = MarkupParser.parse_segments("{i}italic{/}")

      assert segments == [
               %{text: "italic", color: :white, modifiers: [:italic]}
             ]
    end

    test "parses bold and italic together" do
      assert {:ok, segments} = MarkupParser.parse_segments("{b:i}both{/}")

      assert segments == [
               %{text: "both", color: :white, modifiers: [:bold, :italic]}
             ]
    end

    test "parses italic and bold together (order doesn't matter)" do
      assert {:ok, segments} = MarkupParser.parse_segments("{i:b}both{/}")

      assert segments == [
               %{text: "both", color: :white, modifiers: [:italic, :bold]}
             ]
    end
  end

  describe "combined color and modifiers" do
    test "parses bold red text" do
      assert {:ok, segments} = MarkupParser.parse_segments("{red:b}error{/}")

      assert segments == [
               %{text: "error", color: :red, modifiers: [:bold]}
             ]
    end

    test "parses italic bright cyan text" do
      assert {:ok, segments} = MarkupParser.parse_segments("{bright-cyan:i}info{/}")

      assert segments == [
               %{text: "info", color: :bright_cyan, modifiers: [:italic]}
             ]
    end

    test "parses bold italic teal text" do
      assert {:ok, segments} = MarkupParser.parse_segments("{teal:b:i}title{/}")

      assert segments == [
               %{text: "title", color: :teal, modifiers: [:bold, :italic]}
             ]
    end
  end

  describe "nesting" do
    test "nested tag inherits outer color" do
      assert {:ok, segments} = MarkupParser.parse_segments("{red}outer {b}bold{/} normal{/}")

      assert segments == [
               %{text: "outer ", color: :red, modifiers: []},
               %{text: "bold", color: :red, modifiers: [:bold]},
               %{text: " normal", color: :red, modifiers: []}
             ]
    end

    test "nested tag can override color" do
      assert {:ok, segments} = MarkupParser.parse_segments("{red}outer {blue}blue{/} red{/}")

      assert segments == [
               %{text: "outer ", color: :red, modifiers: []},
               %{text: "blue", color: :blue, modifiers: []},
               %{text: " red", color: :red, modifiers: []}
             ]
    end

    test "modifiers accumulate in nesting" do
      assert {:ok, segments} = MarkupParser.parse_segments("{b}bold {i}both{/} bold{/}")

      assert segments == [
               %{text: "bold ", color: :white, modifiers: [:bold]},
               %{text: "both", color: :white, modifiers: [:bold, :italic]},
               %{text: " bold", color: :white, modifiers: [:bold]}
             ]
    end

    test "deeply nested tags work correctly" do
      assert {:ok, segments} =
               MarkupParser.parse_segments("{red}a {b}b {i}c{/} d{/} e{/}")

      assert segments == [
               %{text: "a ", color: :red, modifiers: []},
               %{text: "b ", color: :red, modifiers: [:bold]},
               %{text: "c", color: :red, modifiers: [:bold, :italic]},
               %{text: " d", color: :red, modifiers: [:bold]},
               %{text: " e", color: :red, modifiers: []}
             ]
    end

    test "adjacent tags work correctly" do
      assert {:ok, segments} = MarkupParser.parse_segments("{b}{red}text{/}{/}")

      assert segments == [
               %{text: "text", color: :red, modifiers: [:bold]}
             ]
    end
  end

  describe "escaping" do
    test "{{ produces literal {" do
      assert {:ok, segments} = MarkupParser.parse_segments("Use {{ for braces")

      assert segments == [
               %{text: "Use { for braces", color: :white, modifiers: []}
             ]
    end

    test "multiple escapes work" do
      assert {:ok, segments} = MarkupParser.parse_segments("{{red}} is literal")

      assert segments == [
               %{text: "{red}} is literal", color: :white, modifiers: []}
             ]
    end

    test "escape followed by real tag" do
      assert {:ok, segments} = MarkupParser.parse_segments("{{ then {red}color{/}")

      assert segments == [
               %{text: "{ then ", color: :white, modifiers: []},
               %{text: "color", color: :red, modifiers: []}
             ]
    end
  end

  describe "error handling" do
    test "unclosed tag returns error" do
      assert {:error, msg} = MarkupParser.parse_segments("{red}unclosed")
      assert msg =~ "Unclosed tag"
    end

    test "invalid color returns error" do
      assert {:error, msg} = MarkupParser.parse_segments("{notacolor}text{/}")
      assert msg =~ "Invalid color"
    end

    test "invalid modifier returns error" do
      assert {:error, msg} = MarkupParser.parse_segments("{red:x}text{/}")
      assert msg =~ "Invalid modifier"
    end

    test "extra closing tag returns error" do
      assert {:error, msg} = MarkupParser.parse_segments("{red}text{/}{/}")
      assert msg =~ "Unexpected closing tag"
    end

    test "empty tag returns error" do
      assert {:error, msg} = MarkupParser.parse_segments("{}text")
      assert msg =~ "Empty tag"
    end

    test "malformed closing tag returns error" do
      assert {:error, msg} = MarkupParser.parse_segments("{red}text{/red}")
      assert msg =~ "Closing tag should be {/}"
    end

    test "unclosed brace returns error" do
      assert {:error, msg} = MarkupParser.parse_segments("{red")
      assert msg =~ "Unclosed tag"
    end
  end

  describe "edge cases" do
    test "empty markup string" do
      assert {:ok, segments} = MarkupParser.parse_segments("")
      assert segments == []
    end

    test "just a tag with no text" do
      assert {:ok, segments} = MarkupParser.parse_segments("{red}{/}")
      assert segments == []
    end

    test "multiple consecutive tags" do
      assert {:ok, segments} = MarkupParser.parse_segments("{red}{/}{blue}{/}")
      assert segments == []
    end

    test "whitespace only" do
      assert {:ok, segments} = MarkupParser.parse_segments("   ")

      assert segments == [
               %{text: "   ", color: :white, modifiers: []}
             ]
    end

    test "newlines are preserved" do
      assert {:ok, segments} = MarkupParser.parse_segments("{red}line1\nline2{/}")

      assert segments == [
               %{text: "line1\nline2", color: :red, modifiers: []}
             ]
    end

    test "unicode characters work" do
      assert {:ok, segments} = MarkupParser.parse_segments("{red}emoji 🎮 works{/}")

      assert segments == [
               %{text: "emoji 🎮 works", color: :red, modifiers: []}
             ]
    end
  end

  describe "real-world examples" do
    test "room title with description" do
      markup = """
      {bright-yellow:b}The Throne Room{/}
      A magnificent hall with {amber}golden{/} pillars.
      """

      assert {:ok, segments} = MarkupParser.parse_segments(markup)

      assert segments == [
               %{text: "The Throne Room", color: :bright_yellow, modifiers: [:bold]},
               %{text: "\nA magnificent hall with ", color: :white, modifiers: []},
               %{text: "golden", color: :amber, modifiers: []},
               %{text: " pillars.\n", color: :white, modifiers: []}
             ]
    end

    test "exit list" do
      markup = "{gray}Exits:{/} {bright-cyan}north, south, east{/}"

      assert {:ok, segments} = MarkupParser.parse_segments(markup)

      assert segments == [
               %{text: "Exits:", color: :gray, modifiers: []},
               %{text: " ", color: :white, modifiers: []},
               %{text: "north, south, east", color: :bright_cyan, modifiers: []}
             ]
    end

    test "player list with emote" do
      markup = """
      {bright-green}Alice{/} is here.
      {gray-light:i}Bob is staring off into space.{/}
      """

      assert {:ok, segments} = MarkupParser.parse_segments(markup)

      assert segments == [
               %{text: "Alice", color: :bright_green, modifiers: []},
               %{text: " is here.\n", color: :white, modifiers: []},
               %{
                 text: "Bob is staring off into space.",
                 color: :gray_light,
                 modifiers: [:italic]
               },
               %{text: "\n", color: :white, modifiers: []}
             ]
    end

    test "error message" do
      markup = "{red:b}Error:{/} Invalid command. Type {bright-cyan}help{/} for assistance."

      assert {:ok, segments} = MarkupParser.parse_segments(markup)

      assert segments == [
               %{text: "Error:", color: :red, modifiers: [:bold]},
               %{text: " Invalid command. Type ", color: :white, modifiers: []},
               %{text: "help", color: :bright_cyan, modifiers: []},
               %{text: " for assistance.", color: :white, modifiers: []}
             ]
    end
  end
end
