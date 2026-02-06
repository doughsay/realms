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
      |> assert_eventual_output("don't see")
      |> assert_eventual_output("banana")
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
      assert_eventual_output(player2_view, "Alice")
      assert_eventual_output(player2_view, "sword")
    end

    test "cannot pick up item already in inventory" do
      room = room_fixture()
      %{player: player, view: view} = connect_player(room: room, name: "Alice")

      create_item_in_inventory(player, name: "wallet")

      view
      |> send_command("get wallet")
      |> assert_eventual_output("don't see")
    end
  end
end
