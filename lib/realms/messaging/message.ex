defmodule Realms.Messaging.Message do
  @moduledoc """
  Represents a message in the game with rich formatting support.

  Messages contain one or more sections, each with its own whitespace handling.
  Content within sections is represented as an AST with support for colors,
  bold, and italic text modifiers.

  ## Section Types
  - `{:pre_wrap, content}` - Word-wrapping section for normal text
  - `{:pre, content}` - Non-wrapping section for ASCII art, maps, tables

  ## Content Nodes
  - `"plain text"` - Plain string
  - `{:color, color_atom, content}` - Colored content
  - `{:bold, content}` - Bold text
  - `{:italic, content}` - Italic text

  Content can be nested arbitrarily.
  """

  @enforce_keys [:id, :timestamp, :sections]
  defstruct [:id, :timestamp, :sections]

  @colors [
    # Grayscale (5)
    :black,
    :gray_dark,
    :gray,
    :gray_light,
    :white,
    # Base (8)
    :red,
    :green,
    :yellow,
    :blue,
    :magenta,
    :cyan,
    :orange,
    :purple,
    # Bright (8)
    :bright_red,
    :bright_green,
    :bright_yellow,
    :bright_blue,
    :bright_magenta,
    :bright_cyan,
    :bright_orange,
    :bright_purple,
    # Extended (11)
    :teal,
    :pink,
    :lime,
    :amber,
    :indigo,
    :violet,
    :rose,
    :emerald,
    :sky,
    :slate,
    :brown
  ]

  @type section_type :: :pre_wrap | :pre
  @type color :: unquote(Enum.reduce(@colors, &{:|, [], [&1, &2]}))
  @type content_node ::
          String.t()
          | {:color, color(), content()}
          | {:bold, content()}
          | {:italic, content()}
  @type content :: content_node() | [content_node()]
  @type section :: {section_type(), content()}

  @type t :: %__MODULE__{
          id: String.t(),
          timestamp: DateTime.t(),
          sections: [section()]
        }

  @doc """
  Create a new message with a generated ID and current timestamp.
  """
  def new(sections) when is_list(sections) do
    %__MODULE__{
      id: Ecto.UUID.generate(),
      timestamp: DateTime.utc_now(),
      sections: sections
    }
  end

  @doc """
  Convenience function for creating a simple text message.
  Useful for migrating existing code that used the old Message.new/2 API.
  """
  def from_text(text, color \\ :white) when is_binary(text) do
    new([{:pre_wrap, [{:color, color, [text]}]}])
  end

  @doc """
  Returns the list of valid color atoms.
  """
  def valid_colors, do: @colors

  @doc """
  Checks if the given atom is a valid color.
  """
  def valid_color?(atom), do: atom in @colors

  @doc """
  Validates a section structure.
  """
  def validate_section({section_type, content})
      when section_type in [:pre_wrap, :pre] do
    validate_content(content)
  end

  def validate_section(_), do: {:error, "Invalid section type"}

  # Content validation helpers

  defp validate_content(text) when is_binary(text), do: :ok

  defp validate_content({:color, color, content}) do
    if valid_color?(color) do
      validate_content(content)
    else
      {:error, "Invalid color: #{inspect(color)}"}
    end
  end

  defp validate_content({:bold, content}), do: validate_content(content)
  defp validate_content({:italic, content}), do: validate_content(content)

  defp validate_content(list) when is_list(list) do
    Enum.reduce_while(list, :ok, fn item, _ ->
      case validate_content(item) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_content(other), do: {:error, "Invalid content node: #{inspect(other)}"}
end
