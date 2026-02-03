defmodule Realms.Commands.Command do
  @moduledoc """
  Behavior for command modules.

  Commands are structs that encapsulate command data.
  Each command module defines its own struct and implements this behavior.
  """

  alias Realms.Commands

  @type t :: struct()

  @callback parse(input :: String.t()) :: {:ok, t()} | :error
  @callback execute(command :: t(), context :: Commands.command_context()) ::
              Commands.command_result()
  @callback description() :: String.t()
  @callback examples() :: [String.t()]

  @optional_callbacks [examples: 0]
end
