defmodule RealmsWeb.Commands.InventoryTest do
  use RealmsWeb.ConnCase, async: false

  import Realms.GameFixtures
  import RealmsWeb.GameTestHelpers

  describe "inventory command" do
    test "shows empty inventory message" do
      room = room_fixture()
      %{view: view} = connect_player(room: room, name: "Alice")

      view
      |> send_command("inventory")
      |> assert_eventual_output("You are carrying:")
    end

    test "lists items in player inventory" do
      room = room_fixture()
      %{player: player, view: view} = connect_player(room: room, name: "Alice")

      create_item_in_inventory(player, name: "sword")
      create_item_in_inventory(player, name: "shield")
      create_item_in_inventory(player, name: "potion")

      view
      |> send_command("inventory")
      |> assert_eventual_output("sword")
      |> assert_eventual_output("shield")
      |> assert_eventual_output("potion")
    end

    test "does not show items from room" do
      room = room_fixture()
      %{player: player, view: view} = connect_player(room: room, name: "Alice")

      create_item_in_inventory(player, name: "wallet")
      create_item_in_room(room, name: "statue")

      view
      |> send_command("inventory")
      |> assert_eventual_output("wallet")
      |> assert_no_output("statue")
    end

    test "works with 'inv' abbreviation" do
      room = room_fixture()
      %{player: player, view: view} = connect_player(room: room, name: "Alice")

      create_item_in_inventory(player, name: "compass")

      view
      |> send_command("inv")
      |> assert_eventual_output("compass")
    end

    test "shows containers in inventory" do
      room = room_fixture()
      %{player: player, view: view} = connect_player(room: room, name: "Alice")

      create_item_in_inventory(player, name: "backpack", is_container: true)

      view
      |> send_command("inventory")
      |> assert_eventual_output("backpack")
    end
  end
end
