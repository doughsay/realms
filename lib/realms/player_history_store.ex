defmodule Realms.PlayerHistoryStore do
  use GenServer
  require Logger

  @table_name :player_histories
  @max_messages 100
  # Increment this to wipe DETS on next deploy
  @schema_version 1

  # Client API
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc "Get all messages for a player"
  def get_history(player_id) do
    GenServer.call(__MODULE__, {:get_history, player_id})
  end

  @doc "Append a message to player's history (enforces 100 limit)"
  def append_message(player_id, message) do
    GenServer.call(__MODULE__, {:append_message, player_id, message})
  end

  @doc "Clear a player's history (optional, for testing)"
  def clear_history(player_id) do
    GenServer.call(__MODULE__, {:clear_history, player_id})
  end

  # Server callbacks
  @impl true
  def init(_opts) do
    dets_path = Application.get_env(:realms, :dets_path)
    File.mkdir_p!(dets_path)
    dets_file = Path.join(dets_path, "player_histories.dets")

    # Check schema version and wipe if outdated
    dets_file = maybe_reset_dets(dets_file, dets_path)

    case :dets.open_file(@table_name,
           file: String.to_charlist(dets_file),
           type: :set
         ) do
      {:ok, table} ->
        # Store current schema version
        :dets.insert(@table_name, {:schema_version, @schema_version})

        Logger.info(
          "PlayerHistoryStore: Opened DETS table at #{dets_file} (schema v#{@schema_version})"
        )

        {:ok, %{table: table}}

      {:error, reason} ->
        Logger.error("PlayerHistoryStore: Failed to open DETS: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  defp maybe_reset_dets(dets_file, dets_path) do
    version_file = Path.join(dets_path, ".dets_schema_version")

    stored_version =
      case File.read(version_file) do
        {:ok, content} -> String.to_integer(String.trim(content))
        _ -> nil
      end

    if stored_version != @schema_version do
      Logger.warning(
        "PlayerHistoryStore: Schema version changed (#{stored_version} -> #{@schema_version}), resetting DETS"
      )

      # Delete old DETS file
      File.rm(dets_file)

      # Write new version
      File.write!(version_file, "#{@schema_version}")
    end

    dets_file
  end

  @impl true
  def handle_call({:get_history, player_id}, _from, state) do
    messages =
      case :dets.lookup(@table_name, player_id) do
        [{^player_id, messages}] -> messages
        [] -> []
      end

    {:reply, messages, state}
  end

  @impl true
  def handle_call({:append_message, player_id, message}, _from, state) do
    existing =
      case :dets.lookup(@table_name, player_id) do
        [{^player_id, messages}] -> messages
        [] -> []
      end

    # Skip if message already exists
    if Enum.any?(existing, fn m -> m.id == message.id end) do
      {:reply, :ok, state}
    else
      new_messages = existing ++ [message]

      new_messages =
        if length(new_messages) > @max_messages do
          Enum.drop(new_messages, length(new_messages) - @max_messages)
        else
          new_messages
        end

      :dets.insert(@table_name, {player_id, new_messages})
      # Force write to disk
      :dets.sync(@table_name)
      {:reply, :ok, state}
    end
  end

  @impl true
  def handle_call({:clear_history, player_id}, _from, state) do
    :dets.delete(@table_name, player_id)
    {:reply, :ok, state}
  end

  @impl true
  def terminate(_reason, _state) do
    :dets.close(@table_name)
    :ok
  end
end
