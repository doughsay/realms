defmodule Realms.MobStarter do
  @moduledoc """
  Starts all mob processes on boot.
  """

  use GenServer

  alias Realms.Game
  alias Realms.MobServer

  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    mobs = Game.list_all_mobs()
    Logger.info("MobStarter: Starting #{length(mobs)} mob(s)")

    for mob <- mobs do
      case MobServer.start_mob(mob) do
        {:ok, _pid} ->
          Logger.info("MobStarter: Started mob #{mob.name} (#{mob.id})")

        {:error, reason} ->
          Logger.warning("MobStarter: Failed to start mob #{mob.name}: #{inspect(reason)}")
      end
    end

    {:ok, %{}}
  end
end
