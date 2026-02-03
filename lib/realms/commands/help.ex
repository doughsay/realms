defmodule Realms.Commands.Help do
  @moduledoc """
  Help command - shows available commands.
  """

  @behaviour Realms.Commands.Command

  alias Realms.Messaging
  alias Realms.Messaging.MessageBuilder

  defstruct []

  @impl true
  def parse("help"), do: {:ok, %__MODULE__{}}
  def parse(_), do: :error

  @impl true
  def execute(%__MODULE__{}, context) do
    message =
      MessageBuilder.new()
      |> MessageBuilder.bold("Available Commands", :bright_yellow)
      |> MessageBuilder.paragraph()
      |> MessageBuilder.bold("Movement:", :cyan)
      |> MessageBuilder.text(
        " north, south, east, west, northeast, northwest, southeast, southwest, up, down, in, out",
        :white
      )
      |> MessageBuilder.newline()
      |> MessageBuilder.bold("say <message>:", :cyan)
      |> MessageBuilder.text(" Chat with players in the same room", :white)
      |> MessageBuilder.newline()
      |> MessageBuilder.bold("look:", :cyan)
      |> MessageBuilder.text(" Show current room description", :white)
      |> MessageBuilder.newline()
      |> MessageBuilder.bold("exits:", :cyan)
      |> MessageBuilder.text(" List available exits", :white)
      |> MessageBuilder.newline()
      |> MessageBuilder.bold("help:", :cyan)
      |> MessageBuilder.text(" Show this message", :white)
      |> MessageBuilder.build()

    Messaging.send_to_player(context.player_id, message)

    :ok
  end

  @impl true
  def description, do: "Show available commands"

  @impl true
  def examples, do: ["help"]
end
