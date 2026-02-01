defmodule Realms.GameTest do
  use Realms.DataCase

  alias Realms.Game

  import Realms.AccountsFixtures

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

    # Create test user and player
    user = user_fixture()

    {:ok, player} =
      Game.create_player(%{
        name: "TestPlayer",
        user_id: user.id,
        spawn_room_id: town_square.id,
        last_seen_at: DateTime.utc_now()
      })

    {:ok, player: player, town_square: town_square, tavern: tavern}
  end

  describe "spawn_player/2" do
    test "sets current_room_id and connection_status to online", %{
      player: player,
      town_square: room
    } do
      {:ok, updated_player} = Game.spawn_player(player, room.id)

      assert updated_player.current_room_id == room.id
      assert updated_player.connection_status == :online
      assert is_nil(updated_player.despawn_reason)
    end

    test "clears despawn_reason when spawning", %{player: player, town_square: room} do
      # First despawn the player with a reason
      {:ok, despawned} = Game.despawn_player(player, "server_restart")
      assert despawned.despawn_reason == "server_restart"

      # Then spawn them again
      {:ok, spawned} = Game.spawn_player(despawned, room.id)
      assert is_nil(spawned.despawn_reason)
      assert spawned.connection_status == :online
    end

    test "updates to different room if already spawned", %{
      player: player,
      town_square: town_square,
      tavern: tavern
    } do
      # Spawn in town square
      {:ok, player} = Game.spawn_player(player, town_square.id)
      assert player.current_room_id == town_square.id

      # Spawn in tavern
      {:ok, player} = Game.spawn_player(player, tavern.id)
      assert player.current_room_id == tavern.id
      assert player.connection_status == :online
    end
  end

  describe "despawn_player/3" do
    test "clears current_room_id and sets connection_status to offline", %{
      player: player,
      town_square: room
    } do
      # First spawn the player
      {:ok, player} = Game.spawn_player(player, room.id)
      assert player.current_room_id == room.id

      # Then despawn
      {:ok, updated_player} = Game.despawn_player(player, "timeout")

      assert is_nil(updated_player.current_room_id)
      assert updated_player.connection_status == :offline
      assert updated_player.despawn_reason == "timeout"
    end

    test "preserves last location in spawn_room_id", %{player: player, town_square: room} do
      # Spawn player
      {:ok, player} = Game.spawn_player(player, room.id)
      original_spawn_room = player.spawn_room_id

      # Despawn
      {:ok, despawned} = Game.despawn_player(player, "server_restart")

      # spawn_room_id should be updated to the room they were in
      assert despawned.spawn_room_id == room.id
      # Unless they didn't move, in which case it stays the same
      assert despawned.spawn_room_id == original_spawn_room || despawned.spawn_room_id == room.id
    end

    test "records despawn reason", %{player: player, town_square: room} do
      {:ok, player} = Game.spawn_player(player, room.id)

      {:ok, despawned} = Game.despawn_player(player, "server_shutdown")
      assert despawned.despawn_reason == "server_shutdown"
    end

    test "handles already despawned player", %{player: player} do
      # Player not spawned yet
      assert is_nil(player.current_room_id)

      {:ok, despawned} = Game.despawn_player(player, "timeout")
      assert is_nil(despawned.current_room_id)
      assert despawned.despawn_reason == "timeout"
    end
  end

  describe "despawn_all_players/1" do
    test "despawns all spawned players", %{town_square: room} do
      # Create multiple players and spawn them
      user1 = user_fixture()
      user2 = user_fixture()
      user3 = user_fixture()

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

      {:ok, player3} =
        Game.create_player(%{
          name: "Player3",
          user_id: user3.id,
          spawn_room_id: room.id,
          last_seen_at: DateTime.utc_now()
        })

      # Spawn all players
      {:ok, player1} = Game.spawn_player(player1, room.id)
      {:ok, player2} = Game.spawn_player(player2, room.id)
      {:ok, player3} = Game.spawn_player(player3, room.id)

      # Verify all are spawned
      assert player1.current_room_id == room.id
      assert player2.current_room_id == room.id
      assert player3.current_room_id == room.id

      # Despawn all
      {:ok, count} = Game.despawn_all_players("server_restart")
      assert count == 3

      # Verify all are despawned
      player1 = Game.get_player!(player1.id)
      player2 = Game.get_player!(player2.id)
      player3 = Game.get_player!(player3.id)

      assert is_nil(player1.current_room_id)
      assert is_nil(player2.current_room_id)
      assert is_nil(player3.current_room_id)

      assert player1.connection_status == :offline
      assert player2.connection_status == :offline
      assert player3.connection_status == :offline

      assert player1.despawn_reason == "server_restart"
      assert player2.despawn_reason == "server_restart"
      assert player3.despawn_reason == "server_restart"
    end

    test "preserves spawn_room_id for all players", %{town_square: room} do
      user = user_fixture()

      {:ok, player} =
        Game.create_player(%{
          name: "Player",
          user_id: user.id,
          spawn_room_id: room.id,
          last_seen_at: DateTime.utc_now()
        })

      {:ok, player} = Game.spawn_player(player, room.id)

      {:ok, _count} = Game.despawn_all_players("server_shutdown")

      player = Game.get_player!(player.id)
      assert player.spawn_room_id == room.id
    end

    test "does not affect already despawned players", %{town_square: room} do
      user1 = user_fixture()
      user2 = user_fixture()

      {:ok, player1} =
        Game.create_player(%{
          name: "Online",
          user_id: user1.id,
          spawn_room_id: room.id,
          last_seen_at: DateTime.utc_now()
        })

      {:ok, player2} =
        Game.create_player(%{
          name: "Offline",
          user_id: user2.id,
          spawn_room_id: room.id,
          last_seen_at: DateTime.utc_now()
        })

      # Only spawn player1
      {:ok, _player1} = Game.spawn_player(player1, room.id)
      # player2 stays despawned

      {:ok, count} = Game.despawn_all_players("server_restart")
      # Only player1 was despawned
      assert count == 1

      # Verify player2 wasn't affected
      player2 = Game.get_player!(player2.id)
      assert is_nil(player2.current_room_id)
      # despawn_reason should be set even though they weren't online
      # Actually, let me check - if they weren't in current_room_id, they shouldn't be updated
      # The query only updates players WHERE current_room_id IS NOT NULL
    end

    test "returns count of 0 when no players are spawned" do
      {:ok, count} = Game.despawn_all_players("server_restart")
      assert count == 0
    end
  end
end
