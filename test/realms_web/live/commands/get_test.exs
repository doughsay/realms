defmodule RealmsWeb.Commands.GetTest do
  use RealmsWeb.ConnCase, async: false

  import Realms.GameFixtures
  import RealmsWeb.GameTestHelpers

  describe "get command" do
    test "picks up item from room into player inventory" do
      room = room_fixture()
      %{player: player, view: view} = connect_player(room: room, name: "Alice")

      apple = create_item_in_room(room, name: "apple")

      view
      |> send_command("get apple")
      |> assert_eventual_output("You pick up apple.")

      # Verify item moved to player's inventory
      assert_item_in_location(apple.id, player.inventory_id)
    end

    test "shows error when item not found" do
      room = room_fixture()
      %{view: view} = connect_player(room: room, name: "Alice")

      view
      |> send_command("get banana")
      |> assert_eventual_output("You don't see 'banana' here.")
    end

    test "players in same room see pickup message" do
      room = room_fixture()

      [%{view: player1_view}, %{view: player2_view}] =
        connect_players([
          [room: room, name: "Alice"],
          [room: room, name: "Bob"]
        ])

      create_item_in_room(room, name: "sword")

      send_command(player1_view, "get sword")

      # Observer should see pickup action
      assert_eventual_output(player2_view, "Alice picks up sword.")
    end

    test "cannot pick up item already in inventory" do
      room = room_fixture()
      %{player: player, view: view} = connect_player(room: room, name: "Alice")

      create_item_in_inventory(player, name: "wallet")

      view
      |> send_command("get wallet")
      |> assert_eventual_output("don't see")
    end

    test "gets first item alphabetically when multiple items match" do
      room = room_fixture()
      %{player: player, view: view} = connect_player(room: room, name: "Alice")

      short_sword = create_item_in_room(room, name: "short sword")
      long_sword = create_item_in_room(room, name: "long sword")

      view
      |> send_command("get sword")
      |> assert_eventual_output("You pick up long sword.")

      # Verify long sword is in inventory, short sword still in room
      assert_item_in_location(long_sword.id, player.inventory_id)
      assert_item_in_location(short_sword.id, room.inventory_id)
    end

    test "can match items using multiple words at start of name" do
      room = room_fixture()
      %{player: player, view: view} = connect_player(room: room, name: "Alice")

      rusty_sword = create_item_in_room(room, name: "rusty iron sword")
      create_item_in_room(room, name: "shiny gold sword")

      view
      |> send_command("get rusty iron")
      |> assert_eventual_output("You pick up rusty iron sword")

      assert_item_in_location(rusty_sword.id, player.inventory_id)
    end

    test "can match items using multiple words in middle of name" do
      room = room_fixture()
      %{player: player, view: view} = connect_player(room: room, name: "Alice")

      ancient_sword = create_item_in_room(room, name: "ancient rusty iron sword")
      create_item_in_room(room, name: "new shiny gold sword")

      view
      |> send_command("get rusty iron")
      |> assert_eventual_output("You pick up ancient rusty iron sword")

      assert_item_in_location(ancient_sword.id, player.inventory_id)
    end
  end
end
