defmodule Realms.PlayerHistoryStore do
  use GenServer
  require Logger

  @table_name :player_histories
  @max_messages 100

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

    case :dets.open_file(@table_name,
           file: String.to_charlist(dets_file),
           type: :set
         ) do
      {:ok, table} ->
        Logger.info("PlayerHistoryStore: Opened DETS table at #{dets_file}")
        {:ok, %{table: table}}

      {:error, reason} ->
        Logger.error("PlayerHistoryStore: Failed to open DETS: #{inspect(reason)}")
        {:stop, reason}
    end
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
