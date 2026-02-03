defmodule Realms.Messaging.Message do
  @moduledoc """
  Represents a rich formatted message in the game.

  Messages are composed of segments, each with text, color, and optional
  modifiers.
  """

  @enforce_keys [:id, :segments, :timestamp]
  defstruct [:id, :segments, :timestamp]

  # Grayscale
  @type color ::
          :black
          | :gray_dark
          | :gray
          | :gray_light
          | :white
          # Base colors
          | :red
          | :green
          | :yellow
          | :blue
          | :magenta
          | :cyan
          | :orange
          | :purple
          # Bright variants
          | :bright_red
          | :bright_green
          | :bright_yellow
          | :bright_blue
          | :bright_magenta
          | :bright_cyan
          | :bright_orange
          | :bright_purple
          # Extended colors
          | :teal
          | :pink
          | :lime
          | :amber
          | :indigo
          | :violet
          | :rose
          | :emerald
          | :sky
          | :slate
          | :brown

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
  Create a new message from segments.
  """
  def new(segments) when is_list(segments) do
    %__MODULE__{
      id: Ecto.UUID.generate(),
      segments: normalize_segments(segments),
      timestamp: DateTime.utc_now()
    }
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
