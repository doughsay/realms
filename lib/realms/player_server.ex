defmodule Realms.PlayerServer do
  @moduledoc """
  GenServer that manages state for a single player.

  One PlayerServer per player (not per Game LiveView).
  Handles PubSub subscriptions, message history, and command execution.
  """
  use GenServer

  alias Realms.Commands
  alias Realms.Game
  alias Realms.Messaging
  alias Realms.Messaging.Message

  require Logger

  @away_timeout to_timeout(second: 10)
  @shutdown_timeout to_timeout(second: 30)
  @max_messages 100
  # Increment this version when the Message struct changes incompatibly
  @message_schema_version 2

  def child_spec(player_id) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [player_id]},
      restart: :transient
    }
  end

  defstruct [
    :player_id,
    :player_name,
    :message_history,
    :connected_views,
    :last_activity_at,
    :dets_table,
    :away_timer_ref,
    :shutdown_timer_ref
  ]

  # Client API

  @doc """
  Ensures a Player GenServer is started for the given player_id.
  Returns {:ok, pid} if started or already running.
  """
  def ensure_started(player_id) do
    case Registry.lookup(Realms.PlayerRegistry, player_id) do
      [{pid, _}] ->
        {:ok, pid}

      [] ->
        case DynamicSupervisor.start_child(
               Realms.PlayerSupervisor,
               {__MODULE__, player_id}
             ) do
          {:ok, pid} ->
            {:ok, pid}

          {:error, {:already_started, pid}} ->
            {:ok, pid}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  @doc """
  Checks if a PlayerServer is running for the given player_id.
  Returns {:ok, pid} if running, :error otherwise.
  """
  def whereis?(player_id) do
    case Registry.lookup(Realms.PlayerRegistry, player_id) do
      [{pid, _}] -> {:ok, pid}
      [] -> :error
    end
  end

  @doc """
  Registers a LiveView process with this player's GenServer.
  Sets up a process monitor to track the view.
  """
  def register_view(player_id, view_pid) do
    GenServer.call(via_tuple(player_id), {:register_view, view_pid})
  end

  @doc """
  Unregisters a LiveView process
  """
  def unregister_view(player_id, view_pid) do
    GenServer.cast(via_tuple(player_id), {:unregister_view, view_pid})
  end

  @doc """
  Handles raw input from a LiveView.
  Parses and executes the command.
  """
  def handle_input(player_id, input) do
    GenServer.cast(via_tuple(player_id), {:handle_input, input})
  end

  @doc """
  Retrieves message history for this player.
  """
  def get_history(player_id) do
    GenServer.call(via_tuple(player_id), :get_history)
  end

  @doc """
  Clears message history for this player.
  """
  def clear_history(player_id) do
    GenServer.cast(via_tuple(player_id), :clear_history)
  end

  @doc """
  Changes room subscriptions for this player.
  Called when the player moves to a new room.
  """
  def change_room_subscription(player_id, old_room_id, new_room_id) do
    GenServer.cast(via_tuple(player_id), {:change_room_subscription, old_room_id, new_room_id})
  end

  # Server Callbacks

  def start_link(player_id) do
    GenServer.start_link(__MODULE__, player_id, name: via_tuple(player_id))
  end

  @impl true
  def init(player_id) do
    Process.flag(:trap_exit, true)

    case Game.get_player(player_id) do
      nil ->
        {:stop, :player_not_found}

      player ->
        table_name = dets_table_name(player_id)
        dets_path = dets_file_path(player_id)
        File.mkdir_p!(Path.dirname(dets_path))

        {:ok, table} =
          :dets.open_file(table_name,
            file: String.to_charlist(dets_path),
            type: :set
          )

        history = load_history_from_dets(table)

        player =
          if is_nil(player.current_room_id) do
            {:ok, updated_player} = Game.spawn_player(player.id, player.spawn_room.id)
            updated_player
          else
            player
          end

        state = %__MODULE__{
          player_id: player_id,
          player_name: player.name,
          message_history: history,
          connected_views: MapSet.new(),
          last_activity_at: DateTime.utc_now(),
          dets_table: table,
          away_timer_ref: nil,
          shutdown_timer_ref: nil
        }

        Messaging.subscribe_to_room(player.current_room_id)
        Messaging.subscribe_to_player(player_id)
        Messaging.subscribe_to_global()

        Messaging.send_to_room(
          player.current_room_id,
          "<green>#{player.name} has arrived!</>",
          exclude: self()
        )

        send_welcome_banner(state.player_id)
        Commands.parse_and_execute("look", %{player_id: state.player_id})

        Logger.info("PlayerServer started for player #{player_id}")

        {:ok, state}
    end
  end

  @impl true
  def handle_call({:register_view, view_pid}, _from, state) do
    Process.monitor(view_pid)
    state = cancel_all_timers(state)
    player = Game.get_player!(state.player_id)

    state =
      if player.connection_status == :away do
        Game.set_player_status(state.player_id, :online)

        Messaging.send_to_room(
          player.current_room_id,
          "<green:i>#{state.player_name}'s eyes snap back into focus.</>",
          exclude: self()
        )

        state
      else
        state
      end

    views = MapSet.put(state.connected_views, view_pid)
    state = %{state | connected_views: views}

    Logger.debug("Registered view #{inspect(view_pid)} for player #{state.player_id}")

    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:get_history, _from, state) do
    {:reply, state.message_history, state}
  end

  @impl true
  def handle_cast({:unregister_view, view_pid}, state) do
    Logger.debug("Unregistered view #{inspect(view_pid)} for player #{state.player_id}")
    {:noreply, disconnect_view(state, view_pid)}
  end

  @impl true
  def handle_cast({:handle_input, input}, state) do
    command_echo = Message.new([{:pre_wrap, [{:color, :gray_dark, ["> #{input}"]}]}])
    state = append_to_history_and_send_to_views(state, command_echo)

    case Commands.parse_and_execute(input, %{player_id: state.player_id}) do
      :ok ->
        {:noreply, %{state | last_activity_at: DateTime.utc_now()}}

      {:error, error_message} ->
        Messaging.send_to_player(state.player_id, "<red>#{error_message}</>")
        {:noreply, %{state | last_activity_at: DateTime.utc_now()}}
    end
  end

  @impl true
  def handle_cast(:clear_history, state) do
    if state.dets_table do
      clear_dets_history(state.dets_table)
    end

    Enum.each(state.connected_views, fn view_pid ->
      send(view_pid, :clear_history)
    end)

    {:noreply, %{state | message_history: []}}
  end

  @impl true
  def handle_cast({:change_room_subscription, old_room_id, new_room_id}, state) do
    Messaging.unsubscribe_from_room(old_room_id)
    Messaging.subscribe_to_room(new_room_id)

    {:noreply, state}
  end

  @impl true
  def handle_info({:game_message, %Message{} = message}, state) do
    state = append_to_history_and_send_to_views(state, message)

    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    Logger.debug("View #{inspect(pid)} went down for player #{state.player_id}")
    {:noreply, disconnect_view(state, pid)}
  end

  @impl true
  def handle_info(:away_timeout, state) do
    if Enum.empty?(state.connected_views) do
      player = Game.get_player!(state.player_id)
      Game.set_player_status(state.player_id, :away)

      Messaging.send_to_room(
        player.current_room_id,
        "<gray-light:i>#{state.player_name}'s eyes glaze over.</>",
        exclude: self()
      )

      state =
        state
        |> Map.put(:away_timer_ref, nil)
        |> schedule_shutdown_timer()

      {:noreply, state}
    else
      {:noreply, %{state | away_timer_ref: nil}}
    end
  end

  @impl true
  def handle_info(:shutdown_timeout, state) do
    if Enum.empty?(state.connected_views) do
      Logger.info("PlayerServer shutting down for player #{state.player_id} (no connected views)")
      cleanup(state)
      {:stop, :normal, state}
    else
      {:noreply, %{state | shutdown_timer_ref: nil}}
    end
  end

  @impl true
  def terminate(_reason, state) do
    if state.dets_table do
      :dets.close(state.dets_table)
    end

    :ok
  end

  # Helper Functions

  defp send_welcome_banner(player_id) do
    banner = Messaging.Banner.banner()
    Messaging.send_to_player(player_id, banner)
  end

  defp cleanup(state) do
    player = Game.get_player!(state.player_id)

    Messaging.send_to_room(
      player.current_room_id,
      "<gray-light>#{state.player_name} disappears in a puff of smoke.</>",
      exclude: self()
    )

    Game.despawn_player(state.player_id, "timeout")

    if state.dets_table do
      Logger.debug("Clearing message history for player #{state.player_id} due to timeout")
      clear_dets_history(state.dets_table)
    end
  end

  defp disconnect_view(state, view_pid) do
    views = MapSet.delete(state.connected_views, view_pid)
    state = %{state | connected_views: views}

    if Enum.empty?(views) do
      schedule_away_timer(state)
    else
      state
    end
  end

  defp clear_dets_history(table) do
    :dets.delete_all_objects(table)
    :dets.insert(table, {:schema_version, @message_schema_version})
    :dets.sync(table)
  end

  defp append_message_to_history(state, message) do
    if message_exists?(state.message_history, message.id) do
      state
    else
      new_history = (state.message_history ++ [message]) |> Enum.take(-@max_messages)

      :dets.insert(state.dets_table, [
        {:schema_version, @message_schema_version},
        {:messages, new_history}
      ])

      :dets.sync(state.dets_table)

      %{state | message_history: new_history}
    end
  end

  defp append_to_history_and_send_to_views(state, message) do
    Enum.each(state.connected_views, fn view_pid ->
      send(view_pid, {:game_message, message})
    end)

    append_message_to_history(state, message)
  end

  defp message_exists?(history, message_id) do
    Enum.any?(history, fn m -> m.id == message_id end)
  end

  # Timer Management Helpers

  defp cancel_all_timers(state) do
    state
    |> cancel_away_timer()
    |> cancel_shutdown_timer()
  end

  defp cancel_away_timer(state) do
    if state.away_timer_ref do
      Process.cancel_timer(state.away_timer_ref)
    end

    %{state | away_timer_ref: nil}
  end

  defp cancel_shutdown_timer(state) do
    if state.shutdown_timer_ref do
      Process.cancel_timer(state.shutdown_timer_ref)
    end

    %{state | shutdown_timer_ref: nil}
  end

  defp schedule_away_timer(state) do
    state = cancel_all_timers(state)
    timer_ref = Process.send_after(self(), :away_timeout, @away_timeout)
    %{state | away_timer_ref: timer_ref}
  end

  defp schedule_shutdown_timer(state) do
    state = cancel_shutdown_timer(state)
    timer_ref = Process.send_after(self(), :shutdown_timeout, @shutdown_timeout)
    %{state | shutdown_timer_ref: timer_ref}
  end

  # DETS Helpers

  defp dets_table_name(player_id) do
    "player_history_#{player_id}"
  end

  defp dets_file_path(player_id) do
    dets_dir = Application.get_env(:realms, :dets_path, "priv/dets")
    Path.join(dets_dir, "player_#{player_id}.dets")
  end

  defp load_history_from_dets(table) do
    stored_version =
      case :dets.lookup(table, :schema_version) do
        [{:schema_version, version}] -> version
        [] -> nil
      end

    if stored_version == @message_schema_version do
      case :dets.lookup(table, :messages) do
        [{:messages, messages}] -> messages
        [] -> []
      end
    else
      Logger.info(
        "Message schema version mismatch (stored: #{inspect(stored_version)}, current: #{@message_schema_version}). Clearing message history."
      )

      clear_dets_history(table)
      []
    end
  end

  # Registry Helper

  defp via_tuple(player_id) do
    {:via, Registry, {Realms.PlayerRegistry, player_id}}
  end
end
