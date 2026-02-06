defmodule RealmsWeb.Commands.DropTest do
  use RealmsWeb.ConnCase, async: false

  import Realms.GameFixtures
  import RealmsWeb.GameTestHelpers

  describe "drop command" do
    test "drops item from player inventory to room" do
      room = room_fixture()
      %{view: view, player: player} = connect_player(room: room, name: "Alice")

      sword = create_item_in_inventory(player, name: "sword")

      view
      |> send_command("drop sword")
      |> assert_eventual_output("You drop sword.")

      # Verify item moved to room's inventory
      assert_item_in_location(sword.id, room.inventory_id)
    end

    test "shows error when item not in inventory" do
      room = room_fixture()
      %{view: view} = connect_player(room: room, name: "Alice")

      view
      |> send_command("drop banana")
      |> assert_eventual_output("aren't carrying")
      |> assert_eventual_output("banana")
    end

    test "players in same room see drop message" do
      room = room_fixture()
      %{player: player1} = create_player(room: room, name: "Alice")

      [%{view: player1_view}, %{view: player2_view}] =
        connect_players([
          [room: room, player: player1],
          [room: room, name: "Bob"]
        ])

      create_item_in_inventory(player1, name: "apple")

      send_command(player1_view, "drop apple")

      # Observer should see drop action
      assert_eventual_output(player2_view, "Alice")
      assert_eventual_output(player2_view, "apple")
    end

    test "cannot drop item from room" do
      room = room_fixture()
      %{view: view} = connect_player(room: room, name: "Alice")

      create_item_in_room(room, name: "statue")

      view
      |> send_command("drop statue")
      |> assert_eventual_output("aren't carrying")
    end
  end
end
