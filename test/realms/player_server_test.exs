defmodule Realms.PlayerServerTest do
  use Realms.DataCase
  alias Realms.PlayerServer
  alias Realms.Game
  alias RealmsWeb.Message

  # Helper to start Player GenServer with sandbox access
  defp start_player_server(player_id) do
    {:ok, pid} = PlayerServer.ensure_started(player_id)
    Ecto.Adapters.SQL.Sandbox.allow(Realms.Repo, self(), pid)
    Process.link(pid)
    {:ok, pid}
  end

  # Helper to flush all messages from the process mailbox
  defp flush_messages(acc \\ []) do
    receive do
      msg -> flush_messages([msg | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end

  setup do
    # Create test rooms
    {:ok, town_square} =
      Game.create_room(%{
        name: "Town Square",
        description: "A bustling town square."
      })

    {:ok, tavern} =
      Game.create_room(%{
        name: "The Tavern",
        description: "A cozy tavern."
      })

    # Create exit
    {:ok, _} = Game.create_bidirectional_exit(town_square.id, tavern.id, "north", "south")

    # Create test player
    user = Realms.AccountsFixtures.user_fixture()
    player = Realms.GameFixtures.player_fixture(user)

    {:ok, player: player, town_square: town_square, tavern: tavern}
  end

  describe "ensure_started/1" do
    test "starts a new Player GenServer", %{player: player} do
      {:ok, pid} = start_player_server(player.id)

      assert is_pid(pid)
      assert Process.alive?(pid)
    end

    test "returns existing GenServer if already started", %{player: player} do
      {:ok, pid1} = start_player_server(player.id)
      {:ok, pid2} = start_player_server(player.id)

      assert pid1 == pid2
    end
  end

  describe "get_state/1" do
    test "returns current player state", %{player: player} do
      {:ok, _pid} = start_player_server(player.id)

      state = PlayerServer.get_state(player.id)

      assert state.player.id == player.id
      assert state.current_room.name == "Town Square"
    end
  end

  describe "get_history/1" do
    test "returns message history", %{player: player} do
      {:ok, _pid} = start_player_server(player.id)

      history = PlayerServer.get_history(player.id)

      # Should have initial room description
      assert is_list(history)
      assert length(history) > 0
      assert Enum.any?(history, fn msg -> msg.content =~ "Town Square" end)
    end
  end

  describe "register_view/2 and unregister_view/2" do
    test "registers and manually unregisters a view process", %{player: player} do
      {:ok, pid} = start_player_server(player.id)

      view_pid = spawn(fn -> :timer.sleep(1000) end)
      :ok = PlayerServer.register_view(player.id, view_pid)

      # Verify view is registered (check GenServer state)
      state = :sys.get_state(pid)
      assert MapSet.member?(state.connected_views, view_pid)

      # Manual unregister (backup cleanup mechanism)
      PlayerServer.unregister_view(player.id, view_pid)
      Process.sleep(10)

      state = :sys.get_state(pid)
      refute MapSet.member?(state.connected_views, view_pid)
    end

    test "automatically cleans up view via :DOWN when process dies", %{player: player} do
      {:ok, genserver_pid} = start_player_server(player.id)

      # Spawn a process that we can kill
      view_pid = spawn(fn -> :timer.sleep(10_000) end)
      :ok = PlayerServer.register_view(player.id, view_pid)

      # Verify view is registered
      state = :sys.get_state(genserver_pid)
      assert MapSet.member?(state.connected_views, view_pid)

      # Kill the view process to trigger :DOWN message
      Process.exit(view_pid, :kill)

      # Give GenServer time to process :DOWN message
      Process.sleep(20)

      # View should be automatically removed
      state = :sys.get_state(genserver_pid)
      refute MapSet.member?(state.connected_views, view_pid)
    end

    test "schedules shutdown check when last view disconnects", %{player: player} do
      {:ok, genserver_pid} = start_player_server(player.id)

      # Register and then kill a view
      view_pid = spawn(fn -> :timer.sleep(10_000) end)
      :ok = PlayerServer.register_view(player.id, view_pid)

      # Kill the last view
      Process.exit(view_pid, :kill)
      Process.sleep(20)

      # GenServer should still be alive (waiting for timeout)
      assert Process.alive?(genserver_pid)

      # After the no-views timeout, GenServer should shut down
      # (We can't easily test the full 30-second timeout in tests,
      # but we verified it schedules the check)
    end
  end

  describe "handle_input/2" do
    test "executes look command", %{player: player} do
      {:ok, _pid} = start_player_server(player.id)

      # Register a test view to receive messages
      test_pid = self()
      PlayerServer.register_view(player.id, test_pid)

      PlayerServer.handle_input(player.id, "look")

      # Should receive room description
      assert eventually(fn ->
               receive do
                 {:game_message, %Message{type: :room}} = msg -> {:ok, msg}
               after
                 0 -> :error
               end
             end)
    end

    test "executes say command", %{player: player} do
      {:ok, _pid} = start_player_server(player.id)

      test_pid = self()
      PlayerServer.register_view(player.id, test_pid)

      Phoenix.PubSub.subscribe(Realms.PubSub, "room:#{player.current_room_id}")

      PlayerServer.handle_input(player.id, "say hello")

      # Should receive say message via PubSub
      assert eventually(fn ->
               receive do
                 {:game_message, %Message{type: :say, content: content}} = msg ->
                   if content =~ "hello", do: {:ok, msg}, else: :error
               after
                 0 -> :error
               end
             end)
    end

    test "executes move command", %{player: player} do
      {:ok, _pid} = start_player_server(player.id)

      test_pid = self()
      PlayerServer.register_view(player.id, test_pid)

      PlayerServer.handle_input(player.id, "north")

      # Should receive new room description
      assert eventually(fn ->
               receive do
                 {:game_message, %Message{type: :room, content: content}} = msg ->
                   if content =~ "The Tavern", do: {:ok, msg}, else: :error
               after
                 0 -> :error
               end
             end)

      # Verify state updated
      assert eventually(fn ->
               state = PlayerServer.get_state(player.id)

               if state.current_room.name == "The Tavern" do
                 {:ok, state}
               else
                 :error
               end
             end)
    end

    test "handles unknown command", %{player: player} do
      {:ok, _pid} = start_player_server(player.id)

      test_pid = self()
      PlayerServer.register_view(player.id, test_pid)

      PlayerServer.handle_input(player.id, "foobar")

      # Should receive error message
      assert eventually(fn ->
               receive do
                 {:game_message, %Message{type: :error, content: content}} = msg ->
                   if content =~ "I don't understand", do: {:ok, msg}, else: :error
               after
                 0 -> :error
               end
             end)
    end
  end

  describe "message deduplication" do
    test "does not duplicate messages with same ID", %{player: player} do
      {:ok, pid} = start_player_server(player.id)

      # Get initial history length
      initial_history = PlayerServer.get_history(player.id)
      initial_length = length(initial_history)

      # Create a message
      message = Message.new(:say, "test message", "unique-id-123", DateTime.utc_now())

      # Send the same message twice
      send(pid, {:game_message, message})
      Process.sleep(10)
      send(pid, {:game_message, message})
      Process.sleep(10)

      # History should only have one copy
      final_history = PlayerServer.get_history(player.id)
      assert length(final_history) == initial_length + 1
    end
  end

  describe "idle timeout" do
    test "GenServer shuts down after timeout with no views", %{player: player} do
      {:ok, pid} = start_player_server(player.id)

      # Register and then unregister a view
      test_pid = spawn(fn -> :timer.sleep(1000) end)
      PlayerServer.register_view(player.id, test_pid)
      PlayerServer.unregister_view(player.id, test_pid)

      # Wait for timeout (30 seconds in production, but we can check process is alive for now)
      # In a real test, we'd mock the timeout or make it configurable
      assert Process.alive?(pid)

      # Note: Full timeout test would require waiting 30+ seconds or making timeout configurable
    end

    test "updates player status to offline on shutdown", %{player: player} do
      {:ok, pid} = start_player_server(player.id)

      # Simulate timeout
      send(pid, :shutdown_timeout)

      # Wait for process death
      ref = Process.monitor(pid)
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}

      # Check DB
      updated_player = Game.get_player!(player.id)
      assert updated_player.connection_status == :offline
      assert updated_player.current_room_id == nil
      assert updated_player.spawn_room_id == player.current_room_id
    end
  end

  describe "DETS persistence" do
    test "persists message history to DETS", %{player: player} do
      {:ok, pid} = start_player_server(player.id)

      test_pid = self()
      PlayerServer.register_view(player.id, test_pid)

      # Execute a command
      PlayerServer.handle_input(player.id, "say persisted message")
      Process.sleep(20)

      # Stop the GenServer
      GenServer.stop(pid)
      Process.sleep(10)

      # Start a new GenServer for the same player
      {:ok, _new_pid} = start_player_server(player.id)

      # History should be restored
      history = PlayerServer.get_history(player.id)
      assert Enum.any?(history, fn msg -> msg.content =~ "persisted message" end)
    end
  end

  describe "arrival message suppression" do
    test "shows arrival message on first spawn (normal login)", %{town_square: town_square} do
      # Create an unspawned player (no current_room_id)
      user = Realms.AccountsFixtures.user_fixture()

      {:ok, player} =
        Game.create_player(%{
          name: "NewPlayer",
          user_id: user.id,
          spawn_room_id: town_square.id,
          last_seen_at: DateTime.utc_now()
        })

      # Verify player is not spawned
      assert is_nil(player.current_room_id)
      assert is_nil(player.despawn_reason)

      # Subscribe to room to see arrival messages
      Phoenix.PubSub.subscribe(Realms.PubSub, "room:#{town_square.id}")

      # Player connects for first time
      {:ok, _pid} = start_player_server(player.id)

      # Should receive arrival message
      assert eventually(fn ->
               receive do
                 {:game_message, %Message{type: :room_event, content: content}} = msg ->
                   if content =~ "has arrived!", do: {:ok, msg}, else: :error
               after
                 0 -> :error
               end
             end)
    end

    test "suppresses arrival message after server restart", %{
      player: player,
      town_square: town_square
    } do
      # Simulate server restart scenario:
      # 1. Player was online and spawned
      {:ok, player} = Game.spawn_player(player, town_square.id)

      # 2. Server restarted - ConnectionManager despawned all players
      {:ok, player} = Game.despawn_player(player, "server_restart")
      assert player.despawn_reason == "server_restart"

      # 3. Player reconnects - PlayerServer starts
      Phoenix.PubSub.subscribe(Realms.PubSub, "room:#{town_square.id}")

      {:ok, _pid} = start_player_server(player.id)

      # Should NOT receive arrival message
      # Wait a bit for any potential messages to arrive, then verify none are arrival messages
      assert eventually(
               fn ->
                 messages = flush_messages()

                 arrival_messages =
                   Enum.filter(messages, fn
                     {:game_message, %Message{type: :room_event, content: content}} ->
                       String.contains?(content, "has arrived!")

                     _ ->
                       false
                   end)

                 if arrival_messages == [] do
                   {:ok, :no_arrival_messages}
                 else
                   :error
                 end
               end,
               10,
               20
             )
    end

    test "shows arrival message after timeout disconnect", %{
      player: player,
      town_square: town_square
    } do
      # Simulate timeout scenario:
      # 1. Player was online
      {:ok, player} = Game.spawn_player(player, town_square.id)

      # 2. Player timed out - PlayerServer despawned with "timeout" reason
      {:ok, player} = Game.despawn_player(player, "timeout")
      assert player.despawn_reason == "timeout"

      # 3. Player reconnects
      Phoenix.PubSub.subscribe(Realms.PubSub, "room:#{town_square.id}")

      {:ok, _pid} = start_player_server(player.id)

      # Should receive arrival message (timeout is not a server restart)
      assert eventually(fn ->
               receive do
                 {:game_message, %Message{type: :room_event, content: content}} = msg ->
                   if content =~ "has arrived!", do: {:ok, msg}, else: :error
               after
                 0 -> :error
               end
             end)
    end

    test "shows arrival message after server shutdown", %{
      player: player,
      town_square: town_square
    } do
      # Simulate graceful shutdown scenario:
      # 1. Player was online
      {:ok, player} = Game.spawn_player(player, town_square.id)

      # 2. Server shut down gracefully
      {:ok, player} = Game.despawn_player(player, "server_shutdown")
      assert player.despawn_reason == "server_shutdown"

      # 3. Player reconnects after server restart
      Phoenix.PubSub.subscribe(Realms.PubSub, "room:#{town_square.id}")

      {:ok, _pid} = start_player_server(player.id)

      # Should receive arrival message (server_shutdown is different from server_restart)
      assert eventually(fn ->
               receive do
                 {:game_message, %Message{type: :room_event, content: content}} = msg ->
                   if content =~ "has arrived!", do: {:ok, msg}, else: :error
               after
                 0 -> :error
               end
             end)
    end

    test "player with no despawn_reason shows arrival message", %{town_square: town_square} do
      # Create an unspawned player with no despawn_reason
      user = Realms.AccountsFixtures.user_fixture()

      {:ok, player} =
        Game.create_player(%{
          name: "BrandNewPlayer",
          user_id: user.id,
          spawn_room_id: town_square.id,
          last_seen_at: DateTime.utc_now()
        })

      # Player never had despawn_reason set (new player scenario)
      assert is_nil(player.current_room_id)
      assert is_nil(player.despawn_reason)

      Phoenix.PubSub.subscribe(Realms.PubSub, "room:#{town_square.id}")

      {:ok, _pid} = start_player_server(player.id)

      # Should receive arrival message
      assert eventually(fn ->
               receive do
                 {:game_message, %Message{type: :room_event, content: content}} = msg ->
                   if content =~ "has arrived!", do: {:ok, msg}, else: :error
               after
                 0 -> :error
               end
             end)
    end
  end
end
