defmodule Realms.Messaging.Markup do
  @moduledoc """
  Parses HTML-style markup into message AST.

  ## Syntax

  - `<color>text</>` - Colored text
  - `<b>text</>` - Bold text
  - `<i>text</>` - Italic text
  - `<color:b:i>text</>` - Combined modifiers

  ## Colors

  Use hyphenated names: red, blue, bright-yellow, gray-dark, etc.

  All 37 colors from the MUD palette are supported:
  - Grayscale: black, gray-dark, gray, gray-light, white
  - Base: red, green, yellow, blue, magenta, cyan, orange, purple
  - Bright: bright-red, bright-green, bright-yellow, etc.
  - Extended: teal, pink, lime, amber, indigo, violet, rose, emerald, sky, slate, brown

  ## Literal Characters

  The `<` and `>` characters have special meaning:
  - `<` must either start a valid tag or be escaped with `\\<`
  - To write a literal `<`, use `\\<` (e.g., `x \\< 5`, `I \\<3 cats`)
  - To write a literal `>`, use `\\>`
  - To write a literal backslash, use `\\\\`

  ## Usage

      import Realms.Messaging.Markup

      Message.new([wrap("Hello <red>world</>")])

      Message.new([
        wrap("Description text"),
        pre("ASCII art")
      ])

  ## Examples

      # Simple colors
      wrap("Hello <red>world</>")

      # Bold and italic
      wrap("<b>Warning:</> Please <i>read carefully</>")

      # Combined modifiers
      wrap("<cyan:b>Important:</> <red:i>Danger!</>")

      # Nested tags
      wrap("<red>Red text with <b>bold red</> parts</>")

      # With string interpolation
      wrap("Welcome <cyan>\#{player.name}</>")

      # ASCII art
      pre(\"\"\"
           N
           |
       W---@---E
           |
           S
      \"\"\")
  """

  alias Realms.Messaging.Markup.Parser
  alias Realms.Messaging.Message

  # Public API

  @doc """
  Parse markup for a word-wrapping section.

  Returns a section tuple that can be passed to Message.new/1.

  ## Examples

      wrap("Hello <red>world</>")
      # → {:pre_wrap, ["Hello ", {:color, :red, ["world"]}]}

      wrap(\"\"\"
      <bright-yellow:b>Title</>
      Some text
      \"\"\")
      # → {:pre_wrap, [
      #      {:color, :bright_yellow, [{:bold, ["Title"]}]},
      #      "\\nSome text"
      #    ]}
  """
  @spec wrap(String.t()) :: Message.section()
  def wrap(text) when is_binary(text) do
    {:pre_wrap, parse(text)}
  end

  @doc """
  Parse markup for a non-wrapping section (ASCII art, tables, etc).

  Returns a section tuple that can be passed to Message.new/1.

  ## Examples

      pre(\"\"\"
           N
           |
       W---@---E
           |
           S
      \"\"\")
      # → {:pre, ["     N\\n     |\\n W---@---E\\n     |\\n     S"]}
  """
  @spec pre(String.t()) :: Message.section()
  def pre(text) when is_binary(text) do
    {:pre, parse(text)}
  end

  # Private helpers

  @spec parse(String.t()) :: Message.content()
  defp parse(text) do
    case text |> trim_trailing_newline() |> Parser.parse() do
      {:ok, content} ->
        content

      {:error, reason} ->
        raise RuntimeError, reason
    end
  end

  @spec trim_trailing_newline(String.t()) :: String.t()
  defp trim_trailing_newline(text) do
    # Only trim a single trailing newline (not all of them). This is because
    # Elixir heredocs (\"\"\" ... \"\"\") add a trailing newline.
    if String.ends_with?(text, "\n") do
      String.slice(text, 0..-2//1)
    else
      text
    end
  end
end
