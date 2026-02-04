defmodule Realms.Commands.Crash do
  @moduledoc """
  Test command that intentionally crashes to verify error handling.
  """

  @behaviour Realms.Commands.Command

  defstruct []

  @impl true
  def parse("crash"), do: {:ok, %__MODULE__{}}
  def parse(_), do: :error

  @impl true
  def execute(%__MODULE__{}, _context) do
    raise "This command intentionally crashes for testing error handling!"
  end

  @impl true
  def description, do: "Intentionally crash (for testing)"

  @impl true
  def examples, do: ["crash"]
end
