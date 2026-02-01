defmodule Realms.PlayerServer do
  @moduledoc """
  GenServer that manages state for a single player.

  One PlayerServer per player (not per Game LiveView).
  Handles PubSub subscriptions, message history, and command execution.
  """
  use GenServer
  require Logger

  alias Realms.Game
  alias RealmsWeb.Message

  @no_views_timeout :timer.seconds(30)
  @max_messages 100

  def child_spec(player_id) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [player_id]},
      # Don't restart on :normal or :shutdown exits
      restart: :transient
    }
  end

  defstruct [
    :player_id,
    :player,
    :current_room_id,
    :message_history,
    :connected_views,
    :last_activity_at,
    :dets_table
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

          # Race condition: another process started it between our Registry check and now
          {:error, {:already_started, pid}} ->
            {:ok, pid}

          {:error, reason} ->
            {:error, reason}
        end
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
  Gets the current player state.
  Returns %{player: player, current_room: room}.
  """
  def get_state(player_id) do
    GenServer.call(via_tuple(player_id), :get_state)
  end

  @doc """
  Retrieves message history for this player.
  """
  def get_history(player_id) do
    GenServer.call(via_tuple(player_id), :get_history)
  end

  # Server Callbacks

  def start_link(player_id) do
    GenServer.start_link(__MODULE__, player_id, name: via_tuple(player_id))
  end

  @impl true
  def init(player_id) do
    # Load player from database with preloads
    case Game.get_player(player_id) do
      nil ->
        {:stop, :player_not_found}

      player ->
        # Open per-player DETS table
        table_name = dets_table_name(player_id)
        dets_path = dets_file_path(player_id)
        File.mkdir_p!(Path.dirname(dets_path))

        {:ok, table} =
          :dets.open_file(table_name,
            file: String.to_charlist(dets_path),
            type: :set
          )

        # Load history from DETS
        history = load_history_from_dets(table)

        player =
          if is_nil(player.current_room) do
            spawn_room = Game.get_room!(player.spawn_room_id)
            {:ok, updated_player} = Game.update_player(player, %{current_room_id: spawn_room.id})
            updated_player
          else
            player
          end

        # Subscribe to room PubSub
        room_id = player.current_room.id
        Phoenix.PubSub.subscribe(Realms.PubSub, room_topic(room_id))

        state = %__MODULE__{
          player_id: player_id,
          player: player,
          current_room_id: room_id,
          message_history: history,
          connected_views: MapSet.new(),
          last_activity_at: DateTime.utc_now(),
          dets_table: table
        }

        Logger.info("PlayerServer started for player #{player_id}")

        # Show room description if no history (new player or fresh start)
        state =
          if history == [] do
            show_room_description(state)
          else
            state
          end

        {:ok, state}
    end
  end

  @impl true
  def handle_call({:register_view, view_pid}, _from, state) do
    # Monitor the LiveView process
    Process.monitor(view_pid)

    new_views = MapSet.put(state.connected_views, view_pid)

    {:ok, updated_player} = Game.update_player(state.player, %{connection_status: :online})

    new_state = %{state | connected_views: new_views, player: updated_player}

    Logger.debug("Registered view #{inspect(view_pid)} for player #{state.player_id}")

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    result = %{
      player: state.player,
      current_room: state.player.current_room
    }

    {:reply, result, state}
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
    # First, echo the command to all views and store in history
    command_echo = Message.new(:command_echo, "> #{input}")
    state = append_and_broadcast_local(state, command_echo)

    # Then parse and execute the command
    new_state =
      input
      |> parse_command()
      |> execute_command(state)

    {:noreply, %{new_state | last_activity_at: DateTime.utc_now()}}
  end

  @impl true
  def handle_info({:game_message, %Message{} = message}, state) do
    # Deduplicate and store message
    new_state = append_message_to_history(state, message)

    # Forward to all connected views
    broadcast_to_views(new_state, {:game_message, message})

    {:noreply, new_state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    # LiveView crashed or terminated - cleanup
    Logger.debug("View #{inspect(pid)} went down for player #{state.player_id}")
    {:noreply, disconnect_view(state, pid)}
  end

  @impl true
  def handle_info(:check_no_views_timeout, state) do
    if MapSet.size(state.connected_views) == 0 do
      # Still no views after timeout - shutdown
      Logger.info("PlayerServer shutting down for player #{state.player_id} (no connected views)")
      cleanup(state)
      {:stop, :normal, state}
    else
      # View reconnected in the meantime - stay alive
      {:noreply, state}
    end
  end

  @impl true
  def terminate(_reason, state) do
    Logger.info("PlayerServer terminated for player #{state.player_id}")
    :ok
  end

  # Command Parser

  defp parse_command(""), do: :empty
  defp parse_command("look"), do: :look
  defp parse_command("exits"), do: :exits
  defp parse_command("help"), do: :help
  defp parse_command("say" <> message), do: {:say, String.trim(message)}

  defp parse_command(command) do
    direction = String.downcase(command)

    if direction in ~w(north south east west northeast northwest southeast southwest up down in out) do
      {:move, direction}
    else
      {:unknown, command}
    end
  end

  # Command Executor

  defp execute_command(:empty, state), do: state

  defp execute_command(:look, state) do
    show_room_description(state)
  end

  defp execute_command(:exits, state) do
    message = Message.new(:info, format_exits(state.player.current_room))
    append_and_broadcast_local(state, message)
  end

  defp execute_command(:help, state) do
    help_text = """
    Available commands:
    - Movement: north, south, east, west, northeast, northwest, southeast, southwest, up, down, in, out
    - say <message>: Chat with players in the same room
    - look: Show current room description
    - exits: List available exits
    - help: Show this message
    """

    message = Message.new(:info, help_text)
    append_and_broadcast_local(state, message)
  end

  defp execute_command({:say, message_text}, state) do
    if String.trim(message_text) == "" do
      message = Message.new(:error, "Say what?")
      append_and_broadcast_local(state, message)
    else
      broadcast_say(state.current_room_id, state.player.name, message_text)
      state
    end
  end

  defp execute_command({:move, direction}, state) do
    old_room_id = state.current_room_id
    player = state.player

    case Game.move_player(player, direction) do
      {:ok, new_room} ->
        # 1. Broadcast departure to old room
        broadcast_departure(old_room_id, player.name, direction)

        # 2. Switch room subscriptions
        Phoenix.PubSub.unsubscribe(Realms.PubSub, room_topic(old_room_id))
        Phoenix.PubSub.subscribe(Realms.PubSub, room_topic(new_room.id))

        # 3. Broadcast arrival to new room
        reverse_dir = reverse_direction(direction)
        broadcast_arrival(new_room.id, player.name, reverse_dir)

        # 4. Update state and show new room
        updated_player = Game.get_player!(player.id)

        new_state = %{state | player: updated_player, current_room_id: new_room.id}
        show_room_description(new_state)

      {:error, :no_exit} ->
        message = Message.new(:error, "You can't go that way.")
        append_and_broadcast_local(state, message)
    end
  end

  defp execute_command({:unknown, command}, state) do
    message = Message.new(:error, "I don't understand '#{command}'. Type 'help' for commands.")
    append_and_broadcast_local(state, message)
  end

  # Helper Functions

  defp cleanup(state) do
    :dets.insert(state.dets_table, {:messages, state.message_history})
    :dets.close(state.dets_table)

    Game.update_player(state.player, %{
      connection_status: :offline,
      spawn_room_id: state.current_room_id,
      current_room_id: nil
    })
  end

  defp disconnect_view(state, view_pid) do
    new_views = MapSet.delete(state.connected_views, view_pid)
    state = %{state | connected_views: new_views}

    if MapSet.size(new_views) == 0 do
      {:ok, updated_player} = Game.update_player(state.player, %{connection_status: :away})
      Process.send_after(self(), :check_no_views_timeout, @no_views_timeout)
      %{state | player: updated_player}
    else
      state
    end
  end

  defp show_room_description(state) do
    room = state.player.current_room
    current_player_id = state.player_id

    other_players =
      room.id
      |> Game.players_in_room()
      |> Enum.reject(&(&1.id == current_player_id))

    content = """
    #{room.name}
    #{room.description}

    #{format_exits(room)}
    """

    state = append_and_broadcast_local(state, Message.new(:room, content))

    # Show other players in a separate message
    if other_players != [] do
      player_names =
        Enum.map_join(other_players, ", ", fn player ->
          if player.connection_status == :away do
            "#{player.name} (staring off into space)"
          else
            player.name
          end
        end)

      message = Message.new(:players, "Also here: #{player_names}")
      append_and_broadcast_local(state, message)
    else
      state
    end
  end

  defp format_exits(room) do
    exits = Game.list_exits_from_room(room.id)

    if exits == [] do
      "Obvious exits: none"
    else
      exit_list =
        exits
        |> Enum.map(& &1.direction)
        |> Enum.sort()
        |> Enum.join(", ")

      "Obvious exits: #{exit_list}"
    end
  end

  defp append_message_to_history(state, message) do
    if message_exists?(state.message_history, message.id) do
      state
    else
      new_history = (state.message_history ++ [message]) |> Enum.take(-@max_messages)

      # Write to DETS asynchronously
      :dets.insert(state.dets_table, {:messages, new_history})
      :dets.sync(state.dets_table)

      %{state | message_history: new_history}
    end
  end

  defp append_and_broadcast_local(state, message) do
    new_state = append_message_to_history(state, message)
    broadcast_to_views(new_state, {:game_message, message})
    new_state
  end

  defp broadcast_to_views(state, message) do
    Enum.each(state.connected_views, fn view_pid ->
      send(view_pid, message)
    end)
  end

  defp message_exists?(history, message_id) do
    Enum.any?(history, fn m -> m.id == message_id end)
  end

  # PubSub Helpers

  defp room_topic(room_id), do: "room:#{room_id}"

  defp broadcast_say(room_id, player_name, text) do
    message =
      Message.new(
        :say,
        "#{player_name} says: #{text}",
        Ecto.UUID.generate(),
        DateTime.utc_now()
      )

    Phoenix.PubSub.broadcast(
      Realms.PubSub,
      room_topic(room_id),
      {:game_message, message}
    )
  end

  defp broadcast_departure(room_id, player_name, direction) do
    message =
      Message.new(
        :room_event,
        "#{player_name} leaves to the #{direction}.",
        Ecto.UUID.generate(),
        DateTime.utc_now()
      )

    Phoenix.PubSub.broadcast_from(
      Realms.PubSub,
      self(),
      room_topic(room_id),
      {:game_message, message}
    )
  end

  defp broadcast_arrival(room_id, player_name, from_direction) do
    message =
      Message.new(
        :room_event,
        "#{player_name} arrives from the #{from_direction}.",
        Ecto.UUID.generate(),
        DateTime.utc_now()
      )

    Phoenix.PubSub.broadcast_from(
      Realms.PubSub,
      self(),
      room_topic(room_id),
      {:game_message, message}
    )
  end

  defp reverse_direction("north"), do: "south"
  defp reverse_direction("south"), do: "north"
  defp reverse_direction("east"), do: "west"
  defp reverse_direction("west"), do: "east"
  defp reverse_direction("northeast"), do: "southwest"
  defp reverse_direction("northwest"), do: "southeast"
  defp reverse_direction("southeast"), do: "northwest"
  defp reverse_direction("southwest"), do: "northeast"
  defp reverse_direction("up"), do: "below"
  defp reverse_direction("down"), do: "above"
  defp reverse_direction("in"), do: "outside"
  defp reverse_direction("out"), do: "inside"
  defp reverse_direction(_), do: "somewhere"

  # DETS Helpers

  defp dets_table_name(player_id) do
    # Use the player_id directly as the table name (DETS accepts any term)
    # This avoids creating atoms dynamically which would cause a memory leak
    "player_history_#{player_id}"
  end

  defp dets_file_path(player_id) do
    dets_dir = Application.get_env(:realms, :dets_path, "priv/dets")
    Path.join(dets_dir, "player_#{player_id}.dets")
  end

  defp load_history_from_dets(table) do
    case :dets.lookup(table, :messages) do
      [{:messages, messages}] -> messages
      [] -> []
    end
  end

  # Registry Helper

  defp via_tuple(player_id) do
    {:via, Registry, {Realms.PlayerRegistry, player_id}}
  end
end
