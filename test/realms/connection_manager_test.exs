defmodule Realms.ConnectionManagerTest do
  use Realms.DataCase

  import Realms.AccountsFixtures

  alias Realms.ConnectionManager
  alias Realms.Game

  setup do
    # Create test room
    {:ok, room} =
      Game.create_room(%{
        name: "Town Square",
        description: "A bustling town square."
      })

    {:ok, room: room}
  end

  describe "init/1" do
    test "despawns all players on start", %{room: room} do
      # Create and spawn some players
      user1 = user_fixture()
      user2 = user_fixture()

      {:ok, player1} =
        Game.create_player(%{
          name: "Player1",
          user_id: user1.id,
          spawn_room_id: room.id,
          last_seen_at: DateTime.utc_now()
        })

      {:ok, player2} =
        Game.create_player(%{
          name: "Player2",
          user_id: user2.id,
          spawn_room_id: room.id,
          last_seen_at: DateTime.utc_now()
        })

      {:ok, player1} = Game.spawn_player(player1, room.id)
      {:ok, player2} = Game.spawn_player(player2, room.id)

      # Verify they're spawned
      assert player1.current_room_id == room.id
      assert player2.current_room_id == room.id

      # Start ConnectionManager (simulates server boot)
      {:ok, pid} = GenServer.start(ConnectionManager, [])
      Ecto.Adapters.SQL.Sandbox.allow(Realms.Repo, self(), pid)

      # Wait for init to complete
      Process.sleep(50)

      # Verify all players are despawned
      player1 = Game.get_player!(player1.id)
      player2 = Game.get_player!(player2.id)

      assert is_nil(player1.current_room_id)
      assert is_nil(player2.current_room_id)
      assert player1.connection_status == :offline
      assert player2.connection_status == :offline
      assert player1.despawn_reason == "server_start"
      assert player2.despawn_reason == "server_start"

      # Cleanup
      GenServer.stop(pid)
    end

    test "handles no spawned players gracefully" do
      # Start ConnectionManager with no players
      {:ok, pid} = GenServer.start(ConnectionManager, [])
      Ecto.Adapters.SQL.Sandbox.allow(Realms.Repo, self(), pid)

      # Should not crash
      assert Process.alive?(pid)

      # Cleanup
      GenServer.stop(pid)
    end

    test "sets despawn_reason to server_start", %{room: room} do
      user = user_fixture()

      {:ok, player} =
        Game.create_player(%{
          name: "Player",
          user_id: user.id,
          spawn_room_id: room.id,
          last_seen_at: DateTime.utc_now()
        })

      {:ok, _player} = Game.spawn_player(player, room.id)

      {:ok, pid} = GenServer.start(ConnectionManager, [])
      Ecto.Adapters.SQL.Sandbox.allow(Realms.Repo, self(), pid)
      Process.sleep(50)

      player = Game.get_player!(player.id)
      assert player.despawn_reason == "server_start"

      GenServer.stop(pid)
    end
  end

  describe "terminate/2" do
    test "despawns all players on normal shutdown", %{room: room} do
      user = user_fixture()

      {:ok, player} =
        Game.create_player(%{
          name: "Player",
          user_id: user.id,
          spawn_room_id: room.id,
          last_seen_at: DateTime.utc_now()
        })

      {:ok, _player} = Game.spawn_player(player, room.id)

      {:ok, pid} = GenServer.start(ConnectionManager, [])
      Ecto.Adapters.SQL.Sandbox.allow(Realms.Repo, self(), pid)
      Process.sleep(50)

      # Re-spawn the player to simulate activity after boot
      player = Game.get_player!(player.id)
      {:ok, _player} = Game.spawn_player(player, room.id)

      # Stop normally
      GenServer.stop(pid, :normal)
      Process.sleep(50)

      # Verify player is despawned with server_shutdown reason
      player = Game.get_player!(player.id)
      assert is_nil(player.current_room_id)
      assert player.despawn_reason == "server_shutdown"
    end

    test "despawns all players on shutdown signal", %{room: room} do
      user = user_fixture()

      {:ok, player} =
        Game.create_player(%{
          name: "Player",
          user_id: user.id,
          spawn_room_id: room.id,
          last_seen_at: DateTime.utc_now()
        })

      {:ok, _player} = Game.spawn_player(player, room.id)

      {:ok, pid} = GenServer.start(ConnectionManager, [])
      Ecto.Adapters.SQL.Sandbox.allow(Realms.Repo, self(), pid)
      Process.sleep(50)

      # Re-spawn the player
      player = Game.get_player!(player.id)
      {:ok, _player} = Game.spawn_player(player, room.id)

      # Stop with shutdown reason
      GenServer.stop(pid, :shutdown)
      Process.sleep(50)

      player = Game.get_player!(player.id)
      assert is_nil(player.current_room_id)
      assert player.despawn_reason == "server_shutdown"
    end

    test "sets server_shutdown reason on abnormal termination", %{room: room} do
      user = user_fixture()

      {:ok, player} =
        Game.create_player(%{
          name: "Player",
          user_id: user.id,
          spawn_room_id: room.id,
          last_seen_at: DateTime.utc_now()
        })

      {:ok, _player} = Game.spawn_player(player, room.id)

      {:ok, pid} = GenServer.start(ConnectionManager, [])
      Ecto.Adapters.SQL.Sandbox.allow(Realms.Repo, self(), pid)
      Process.sleep(50)

      # Re-spawn the player
      player = Game.get_player!(player.id)
      {:ok, _player} = Game.spawn_player(player, room.id)

      # Stop with abnormal reason
      GenServer.stop(pid, :some_error)
      Process.sleep(50)

      player = Game.get_player!(player.id)
      assert is_nil(player.current_room_id)
      assert player.despawn_reason == "server_shutdown"
    end
  end

  describe "trap_exit flag" do
    test "has trap_exit enabled to ensure terminate is called" do
      {:ok, pid} = GenServer.start(ConnectionManager, [])
      Ecto.Adapters.SQL.Sandbox.allow(Realms.Repo, self(), pid)

      # Check process flag
      process_info = Process.info(pid, :trap_exit)
      assert {:trap_exit, true} = process_info

      GenServer.stop(pid)
    end
  end
end
