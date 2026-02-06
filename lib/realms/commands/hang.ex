defmodule Realms.Commands.Hang do
  @moduledoc """
  Test command that intentionally hangs forever to verify timeout handling.
  """

  @behaviour Realms.Commands.Command

  alias Realms.Commands.Command

  defstruct []

  @impl Command
  def parse("hang"), do: {:ok, %__MODULE__{}}
  def parse(_), do: :error

  @impl Command
  def execute(%__MODULE__{}, _context) do
    infinite_loop()
  end

  @impl Command
  def description, do: "Intentionally hang forever (for testing)"

  @impl Command
  def examples, do: ["hang"]

  defp infinite_loop do
    Process.sleep(1000)
    infinite_loop()
  end
end
