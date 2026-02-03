defmodule Realms.Messaging.MessageBuilder do
  @moduledoc """
  Fluent API for building rich formatted messages.

  ## Examples

      # Simple colored text
      MessageBuilder.new()
      |> MessageBuilder.text("The Throne Room", :bright_yellow, [:bold])
      |> MessageBuilder.newline()
      |> MessageBuilder.text("A magnificent hall.", :white)
      |> MessageBuilder.build()

      # Using helpers
      MessageBuilder.new()
      |> MessageBuilder.bold("Important!", :bright_red)
      |> MessageBuilder.text(" - ", :gray)
      |> MessageBuilder.italic("This is a note", :cyan)
      |> MessageBuilder.build()
  """

  alias Realms.Messaging.Message

  defstruct segments: []

  @doc "Start building a new message"
  def new, do: %__MODULE__{segments: []}

  @doc "Add text with optional color and modifiers"
  def text(builder, text, color \\ :white, modifiers \\ []) do
    segment = %{text: text, color: color, modifiers: modifiers}
    %{builder | segments: builder.segments ++ [segment]}
  end

  @doc "Add bold text"
  def bold(builder, text, color \\ :white) do
    text(builder, text, color, [:bold])
  end

  @doc "Add italic text"
  def italic(builder, text, color \\ :white) do
    text(builder, text, color, [:italic])
  end

  @doc "Add bold italic text"
  def bold_italic(builder, text, color \\ :white) do
    text(builder, text, color, [:bold, :italic])
  end

  @doc "Add a newline"
  def newline(builder), do: text(builder, "\n")

  @doc "Add a paragraph break (double newline)"
  def paragraph(builder), do: text(builder, "\n\n")

  @doc "Add a space"
  def space(builder), do: text(builder, " ")

  @doc "Conditionally add content"
  def add_if(builder, condition, fun) do
    if condition, do: fun.(builder), else: builder
  end

  @doc "Build the final message"
  def build(%__MODULE__{segments: segments}) do
    Message.new(segments)
  end

  @doc "Create a simple single-color message quickly"
  def simple(text, color \\ :white, modifiers \\ []) do
    new() |> text(text, color, modifiers) |> build()
  end
end
