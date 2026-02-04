defmodule Realms.Commands.Hang do
  @moduledoc """
  Test command that intentionally hangs forever to verify timeout handling.
  """

  @behaviour Realms.Commands.Command

  defstruct []

  @impl true
  def parse("hang"), do: {:ok, %__MODULE__{}}
  def parse(_), do: :error

  @impl true
  def execute(%__MODULE__{}, _context) do
    infinite_loop()
  end

  @impl true
  def description, do: "Intentionally hang forever (for testing)"

  @impl true
  def examples, do: ["hang"]

  defp infinite_loop do
    :timer.sleep(1000)
    infinite_loop()
  end
end
