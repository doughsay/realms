defmodule Realms.Commands do
  @moduledoc """
  Commands context for parsing and executing player commands.

  Commands are parsed into command structs and executed in supervised Tasks for
  crash isolation and non-blocking execution.
  """

  alias Realms.Commands.Command
  alias Realms.Commands.{Look, Help, Exits, Say, Move, Crash, Hang, Clear, Banner}
  alias Realms.Messaging

  require Logger

  @type command_result :: :ok | {:error, String.t()}

  @type command_context :: %{player_id: binary()}

  # Commands in priority order - first match wins
  @commands [Look, Help, Exits, Say, Move, Crash, Hang, Clear, Banner]

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
        {:error, "I don't understand '#{input}'. Type 'help' for commands."}
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

  Launches the command in a supervised Task with error handling and timeout.
  Returns immediately with :ok.
  """
  @spec execute(Command.t(), command_context()) :: :ok
  def execute(%module{} = command, context) do
    {:ok, pid} =
      Task.Supervisor.start_child(Realms.CommandSupervisor, fn ->
        try do
          module.execute(command, context)
        rescue
          error ->
            Logger.error("""
            Command execution failed: #{inspect(module)}
            Error: #{Exception.format(:error, error, __STACKTRACE__)}
            Context: #{inspect(context)}
            """)

            Messaging.send_to_player(
              context.player_id,
              "<red:b>Command error:</> An error occurred while executing that command."
            )

            :ok
        end
      end)

    spawn(fn ->
      ref = Process.monitor(pid)

      receive do
        {:DOWN, ^ref, :process, ^pid, _reason} ->
          :ok
      after
        5_000 ->
          Process.exit(pid, :kill)

          Logger.error("""
          Command execution timeout: #{inspect(module)}
          Context: #{inspect(context)}
          """)

          Messaging.send_to_player(
            context.player_id,
            "<red:b>Command timeout:</> The command took too long to execute and was cancelled."
          )
      end
    end)

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
