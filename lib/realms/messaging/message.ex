defmodule Realms.Messaging.Message do
  @moduledoc """
  Represents a rich formatted message in the game.

  Messages are composed of segments, each with text, color, and optional
  modifiers.
  """

  alias Realms.Messaging.MarkupParser

  @enforce_keys [:id, :segments, :timestamp]
  defstruct [:id, :segments, :timestamp]

  @colors [
    # Grayscale (5)
    :black,
    :gray_dark,
    :gray,
    :gray_light,
    :white,
    # Base colors (8)
    :red,
    :green,
    :yellow,
    :blue,
    :magenta,
    :cyan,
    :orange,
    :purple,
    # Bright variants (8)
    :bright_red,
    :bright_green,
    :bright_yellow,
    :bright_blue,
    :bright_magenta,
    :bright_cyan,
    :bright_orange,
    :bright_purple,
    # Extended colors (11)
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

  @doc "Returns a list of valid message colors."
  def valid_colors, do: @colors

  @type color :: atom()

  @type modifier :: :bold | :italic

  @type segment :: %{
          text: String.t(),
          color: color() | nil,
          modifiers: [modifier()]
        }

  @type t :: %__MODULE__{
          id: String.t(),
          segments: [segment()],
          timestamp: DateTime.t()
        }

  @doc """
  Sigil for creating a message from markup.

  ## Example

      import Realms.Messaging.Message
      ~m"{red}Hello{/}"
  """
  def sigil_m(text, _modifiers) do
    from_markup(text)
  end

  @doc """
  Create a new message from segments.
  """
  def new(segments) when is_list(segments) do
    %__MODULE__{
      id: Ecto.UUID.generate(),
      segments: normalize_segments(segments),
      timestamp: DateTime.utc_now()
    }
  end

  @doc """
  Create a message from markup string.

  On parse error, falls back to creating a plain white message.

  ## Example

      Message.from_markup("{bright-yellow:b}Title{/}")
  """
  def from_markup(markup_text) when is_binary(markup_text) do
    case MarkupParser.parse(markup_text) do
      {:ok, message} ->
        message

      {:error, _reason} ->
        # Fall back to plain text on error
        new([%{text: markup_text, color: :white, modifiers: []}])
    end
  end

  defp normalize_segments(segments) do
    Enum.map(segments, fn
      %{text: _, color: _, modifiers: _} = seg -> seg
      %{text: text, color: color} -> %{text: text, color: color, modifiers: []}
      %{text: text} -> %{text: text, color: :white, modifiers: []}
      text when is_binary(text) -> %{text: text, color: :white, modifiers: []}
    end)
  end
end
