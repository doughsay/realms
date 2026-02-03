defmodule Realms.Commands do
  @moduledoc """
  Commands context for parsing and executing player commands.

  Commands are parsed into command structs and executed in supervised Tasks for
  crash isolation and non-blocking execution.
  """

  alias Realms.Commands.Command
  alias Realms.Commands.{Look, Help, Exits, Say, Move}

  @type command_result :: :ok | {:error, String.t()}

  @type command_context :: %{player_id: binary()}

  # Commands in priority order - first match wins
  @commands [Look, Help, Exits, Say, Move]

  @doc """
  Parses and executes a player input string in the given context.

  Returns the result of execution or an error if parsing fails.
  """
  @spec parse_and_execute(input :: String.t(), command_context()) :: command_result()
  def parse_and_execute(input, context) do
    case parse(input) do
      {:ok, command} ->
        execute(command, context)

      :error ->
        {:error, "Arglebargle, glop-glyf!?!"}
    end
  end

  @doc """
  Parses a player input string into a command struct.

  Returns {:ok, command_struct} or :error if no command matches.
  """
  @spec parse(input :: String.t()) :: {:ok, struct()} | :error
  def parse(input) do
    Enum.find_value(@commands, :error, fn module ->
      case module.parse(input) do
        {:ok, command} -> {:ok, command}
        :error -> false
      end
    end)
  end

  @doc """
  Executes a command struct in the given context.

  Launches the command in a supervised Task.
  Returns immediately with :ok.
  """
  @spec execute(Command.t(), command_context()) :: :ok
  def execute(%module{} = command, context) do
    Task.Supervisor.start_child(
      Realms.CommandSupervisor,
      fn ->
        module.execute(command, context)
      end
    )

    :ok
  end

  @doc """
  Lists all available commands with their descriptions.
  """
  @spec list_commands() :: [{atom(), String.t()}]
  def list_commands do
    Enum.map(@commands, fn module ->
      name =
        module
        |> Module.split()
        |> List.last()
        |> Macro.underscore()
        |> String.to_atom()

      {name, module.description()}
    end)
  end
end
