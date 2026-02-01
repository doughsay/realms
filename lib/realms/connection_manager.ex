defmodule Realms.ConnectionManager do
  @moduledoc """
  Manages player connection lifecycle during server boot and shutdown.

  Ensures database consistency by:
  - Despawning all players on boot (server restart)
  - Despawning all players on graceful shutdown
  """

  use GenServer
  require Logger
  alias Realms.Game

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Process.flag(:trap_exit, true)
    {:ok, count} = Game.despawn_all_players("server_restart")
    Logger.info("ConnectionManager: Despawned #{count} players on server start")
    {:ok, %{}}
  end

  @impl true
  def terminate(reason, _state) do
    despawn_reason =
      case reason do
        :normal -> "server_shutdown"
        :shutdown -> "server_shutdown"
        {:shutdown, _} -> "server_shutdown"
        _ -> "server_restart"
      end

    {:ok, count} = Game.despawn_all_players(despawn_reason)
    Logger.info("ConnectionManager: Despawned #{count} players on shutdown (#{despawn_reason})")

    :ok
  end
end
