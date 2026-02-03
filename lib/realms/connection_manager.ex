defmodule Realms.ConnectionManager do
  @moduledoc """
  Manages player connection lifecycle during server boot and shutdown.

  Ensures database consistency by:
  - Despawning all players on boot (catches abnormal server restarts)
  - Despawning all players on graceful shutdown
  """

  use GenServer

  alias Realms.Game

  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Process.flag(:trap_exit, true)
    {:ok, count} = Game.despawn_all_players("server_start")
    Logger.info("ConnectionManager: Despawned #{count} players on server start")
    {:ok, %{}}
  end

  @impl true
  def terminate(_reason, _state) do
    {:ok, count} = Game.despawn_all_players("server_shutdown")
    Logger.info("ConnectionManager: Despawned #{count} players on shutdown")

    :ok
  end
end
