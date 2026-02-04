defmodule Realms.Messaging.MarkupTest do
  use ExUnit.Case, async: true

  import Realms.Messaging.Markup

  alias Realms.Messaging.Message

  describe "wrap/1" do
    test "parses plain text" do
      assert wrap("Hello world") == {:pre_wrap, ["Hello world"]}
    end

    test "parses single color tag" do
      assert wrap("Hello <red>world</>") ==
               {:pre_wrap, ["Hello ", {:color, :red, ["world"]}]}
    end

    test "parses bold tag" do
      assert wrap("<b>bold text</>") ==
               {:pre_wrap, [{:bold, ["bold text"]}]}
    end

    test "parses italic tag" do
      assert wrap("<i>italic text</>") ==
               {:pre_wrap, [{:italic, ["italic text"]}]}
    end

    test "parses combined color and bold" do
      assert wrap("<red:b>text</>") ==
               {:pre_wrap, [{:bold, [{:color, :red, ["text"]}]}]}
    end

    test "parses combined color, bold, and italic" do
      assert wrap("<cyan:b:i>text</>") ==
               {:pre_wrap, [{:italic, [{:bold, [{:color, :cyan, ["text"]}]}]}]}
    end

    test "parses nested tags" do
      assert wrap("<red>Red with <b>bold red</> parts</>") ==
               {:pre_wrap,
                [
                  {:color, :red, ["Red with ", {:bold, ["bold red"]}, " parts"]}
                ]}
    end

    test "parses multiple tags" do
      assert wrap("Text <red>red</> and <blue>blue</>") ==
               {:pre_wrap,
                [
                  "Text ",
                  {:color, :red, ["red"]},
                  " and ",
                  {:color, :blue, ["blue"]}
                ]}
    end

    test "preserves whitespace" do
      assert wrap("Line 1\n  Indented\n\nBlank above") ==
               {:pre_wrap, ["Line 1\n  Indented\n\nBlank above"]}
    end

    test "trims only trailing newline" do
      assert wrap("Hello\n") == {:pre_wrap, ["Hello"]}
      assert wrap("Hello\n\n") == {:pre_wrap, ["Hello\n"]}
      assert wrap("\nHello\n") == {:pre_wrap, ["\nHello"]}
    end

    test "handles empty string" do
      assert wrap("") == {:pre_wrap, []}
    end

    test "handles string with only newline" do
      assert wrap("\n") == {:pre_wrap, []}
    end

    test "parses color names with hyphens" do
      assert wrap("<bright-yellow>text</>") ==
               {:pre_wrap, [{:color, :bright_yellow, ["text"]}]}

      assert wrap("<gray-dark>text</>") ==
               {:pre_wrap, [{:color, :gray_dark, ["text"]}]}
    end

    test "handles complex nesting" do
      assert wrap("<red>Red <b>bold <i>italic</></></>") ==
               {:pre_wrap,
                [
                  {:color, :red, ["Red ", {:bold, ["bold ", {:italic, ["italic"]}]}]}
                ]}
    end
  end

  describe "pre/1" do
    test "returns pre section type" do
      assert pre("text") == {:pre, ["text"]}
    end

    test "preserves all whitespace for ASCII art" do
      ascii = """
           N
           |
       W---@---E
           |
           S
      """

      expected = "     N\n     |\n W---@---E\n     |\n     S"
      assert pre(ascii) == {:pre, [expected]}
    end

    test "can include color tags in pre sections" do
      assert pre("<red>colored art</>") ==
               {:pre, [{:color, :red, ["colored art"]}]}
    end
  end

  describe "error handling" do
    test "raises on unclosed tag" do
      assert_raise RuntimeError, ~r/Unclosed tag/, fn ->
        wrap("<red>text")
      end
    end

    test "raises on unknown color" do
      assert_raise ArgumentError, ~r/Unknown color: :invalid_color/, fn ->
        wrap("<invalid-color>text</>")
      end
    end

    test "raises on unexpected closing tag" do
      assert_raise RuntimeError, ~r/Unexpected closing tag/, fn ->
        wrap("text</> more")
      end
    end

    test "raises on unknown modifier" do
      assert_raise ArgumentError, ~r/Unknown modifier: x/, fn ->
        wrap("<red:x>text</>")
      end
    end

    test "treats unclosed < at end as literal (smart detection)" do
      # With smart detection, <red without closing > is treated as literal
      assert wrap("<red") == {:pre_wrap, ["<red"]}
    end

    test "treats tag with special characters as literal (smart detection)" do
      # <red!> has invalid character, so it's treated as literal
      # The </> then fails because there's no matching opening tag
      assert_raise RuntimeError, ~r/Unexpected closing tag/, fn ->
        wrap("<red!>text</>")
      end
    end
  end

  describe "color name conversion" do
    test "converts hyphenated to underscored atoms" do
      assert wrap("<bright-red>text</>") ==
               {:pre_wrap, [{:color, :bright_red, ["text"]}]}

      assert wrap("<gray-light>text</>") ==
               {:pre_wrap, [{:color, :gray_light, ["text"]}]}
    end

    test "validates all 37 colors exist" do
      # Grayscale
      for color <- ["black", "gray-dark", "gray", "gray-light", "white"] do
        assert {:pre_wrap, _} = wrap("<#{color}>text</>")
      end

      # Base
      for color <- ["red", "green", "yellow", "blue", "magenta", "cyan", "orange", "purple"] do
        assert {:pre_wrap, _} = wrap("<#{color}>text</>")
      end

      # Bright
      for color <- [
            "bright-red",
            "bright-green",
            "bright-yellow",
            "bright-blue",
            "bright-magenta",
            "bright-cyan",
            "bright-orange",
            "bright-purple"
          ] do
        assert {:pre_wrap, _} = wrap("<#{color}>text</>")
      end

      # Extended
      for color <- [
            "teal",
            "pink",
            "lime",
            "amber",
            "indigo",
            "violet",
            "rose",
            "emerald",
            "sky",
            "slate",
            "brown"
          ] do
        assert {:pre_wrap, _} = wrap("<#{color}>text</>")
      end
    end
  end

  describe "literal characters and escaping" do
    test "smart detection: < followed by space is literal" do
      assert wrap("x < 5") == {:pre_wrap, ["x < 5"]}
    end

    test "smart detection: < followed by digit is literal" do
      assert wrap("I <3 cats") == {:pre_wrap, ["I <3 cats"]}
      assert wrap("x <10") == {:pre_wrap, ["x <10"]}
    end

    test "smart detection: << is literal" do
      assert wrap("Use <<>> for binaries") == {:pre_wrap, ["Use <<>> for binaries"]}
    end

    test "smart detection: math comparisons work" do
      assert wrap("if x < 10 and y > 5") == {:pre_wrap, ["if x < 10 and y > 5"]}
    end

    test "smart detection: arrows work" do
      assert wrap("Click here -->") == {:pre_wrap, ["Click here -->"]}
    end

    test "smart detection: < followed by invalid tag name is literal" do
      assert wrap("x<y") == {:pre_wrap, ["x<y"]}
      assert wrap("a<-b") == {:pre_wrap, ["a<-b"]}
    end

    test "backslash escapes: \\< produces <" do
      assert wrap("Use \\<red> for color") == {:pre_wrap, ["Use <red> for color"]}
    end

    test "backslash escapes: \\> produces >" do
      assert wrap("Greater \\> than") == {:pre_wrap, ["Greater > than"]}
    end

    test "backslash escapes: \\\\ produces \\" do
      assert wrap("Backslash: \\\\") == {:pre_wrap, ["Backslash: \\"]}
    end

    test "backslash escapes: lone backslash is literal" do
      assert wrap("trailing\\") == {:pre_wrap, ["trailing\\"]}
    end

    test "can escape entire tag to show as literal" do
      assert wrap("To use colors: \\<red>text\\</>") ==
               {:pre_wrap, ["To use colors: <red>text</>"]}
    end

    test "mix of escaped and real tags" do
      assert wrap("\\<red> is syntax, but <red>this</> is colored") ==
               {:pre_wrap, ["<red> is syntax, but ", {:color, :red, ["this"]}, " is colored"]}
    end
  end

  describe "interpolation" do
    test "works with string interpolation" do
      name = "Alice"

      assert wrap("Welcome <cyan>#{name}</>") ==
               {:pre_wrap, ["Welcome ", {:color, :cyan, ["Alice"]}]}
    end

    test "interpolated values can contain literal <" do
      value = "x < 5"
      assert wrap("Check: #{value}") == {:pre_wrap, ["Check: x < 5"]}
    end

    test "interpolated values can contain >" do
      value = "x > 5"
      assert wrap("Check: #{value}") == {:pre_wrap, ["Check: x > 5"]}
    end

    test "complex interpolation with tags" do
      title = "The Grand Hall"
      desc = "A magnificent room."

      result =
        wrap("""
        <bright-yellow:b>#{title}</>
        #{desc}
        """)

      assert result ==
               {:pre_wrap,
                [
                  {:bold, [{:color, :bright_yellow, ["The Grand Hall"]}]},
                  "\nA magnificent room."
                ]}
    end
  end

  describe "integration with Message" do
    test "creates valid message with wrap" do
      message = Message.new([wrap("Hello <red>world</>")])

      assert %Message{sections: [{:pre_wrap, _}]} = message
      assert :ok = Message.validate_section(hd(message.sections))
    end

    test "creates valid message with pre" do
      message = Message.new([pre("ASCII art")])

      assert %Message{sections: [{:pre, _}]} = message
      assert :ok = Message.validate_section(hd(message.sections))
    end

    test "creates valid message with multiple sections" do
      message =
        Message.new([
          wrap("<bright-yellow:b>Title</>"),
          wrap("Description"),
          pre("Map"),
          wrap("Exits: <cyan>north</>")
        ])

      assert %Message{sections: [_, _, _, _]} = message

      for section <- message.sections do
        assert :ok = Message.validate_section(section)
      end
    end

    test "validates all color names are correct" do
      # This ensures our color_name_to_atom conversion produces valid colors
      for color <- Message.valid_colors() do
        color_str = Atom.to_string(color) |> String.replace("_", "-")
        message = Message.new([wrap("<#{color_str}>text</>")])
        assert :ok = Message.validate_section(hd(message.sections))
      end
    end
  end

  describe "edge cases" do
    test "empty tags produce empty content" do
      assert wrap("<red></>") == {:pre_wrap, [{:color, :red, []}]}
    end

    test "whitespace-only content preserved" do
      assert wrap("<red>   </>") == {:pre_wrap, [{:color, :red, ["   "]}]}
      assert wrap("<red>\n\n</>") == {:pre_wrap, [{:color, :red, ["\n\n"]}]}
    end

    test "multiple consecutive tags" do
      assert wrap("<red>A</><blue>B</><green>C</>") ==
               {:pre_wrap,
                [
                  {:color, :red, ["A"]},
                  {:color, :blue, ["B"]},
                  {:color, :green, ["C"]}
                ]}
    end

    test "tag at start" do
      assert wrap("<red>start</>") == {:pre_wrap, [{:color, :red, ["start"]}]}
    end

    test "tag at end" do
      assert wrap("end <red>tag</>") ==
               {:pre_wrap, ["end ", {:color, :red, ["tag"]}]}
    end

    test "only tags, no plain text" do
      assert wrap("<red>A</><blue>B</>") ==
               {:pre_wrap, [{:color, :red, ["A"]}, {:color, :blue, ["B"]}]}
    end
  end
end
