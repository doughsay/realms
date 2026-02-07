defmodule RealmsWeb.Commands.GetFromTest do
  use RealmsWeb.ConnCase, async: false

  import Realms.GameFixtures
  import RealmsWeb.GameTestHelpers

  describe "get_from command" do
    test "gets item from container in inventory" do
      room = room_fixture()
      %{player: player, view: view} = connect_player(room: room, name: "Alice")

      backpack = create_item_in_inventory(player, name: "backpack", is_container: true)
      backpack_inventory_id = Realms.Game.get_container_inventory_id(backpack)
      apple = item_fixture(%{location_id: backpack_inventory_id, name: "apple"})

      view
      |> send_command("get apple from backpack")
      |> assert_eventual_output("You take apple from backpack.")

      assert_item_in_location(apple.id, player.inventory_id)
    end

    test "shows error when item not in container" do
      room = room_fixture()
      %{player: player, view: view} = connect_player(room: room, name: "Alice")

      create_item_in_inventory(player, name: "chest", is_container: true)

      view
      |> send_command("get banana from chest")
      |> assert_eventual_output("don't see")
      |> assert_eventual_output("banana")
    end

    test "shows error when container not found" do
      room = room_fixture()
      %{view: view} = connect_player(room: room, name: "Alice")

      view
      |> send_command("get apple from chest")
      |> assert_eventual_output("not holding")
      |> assert_eventual_output("chest")
    end

    test "players in room see get action" do
      room = room_fixture()
      %{player: player1} = create_player(room: room, name: "Alice")

      [%{view: player1_view}, %{view: player2_view}] =
        connect_players([
          [room: room, player: player1],
          [room: room, name: "Bob"]
        ])

      chest = create_item_in_inventory(player1, name: "chest", is_container: true)
      chest_inventory_id = Realms.Game.get_container_inventory_id(chest)
      item_fixture(%{location_id: chest_inventory_id, name: "jewel"})

      send_command(player1_view, "get jewel from chest")

      # Observer should see the action
      assert_eventual_output(player2_view, "Alice")
      assert_eventual_output(player2_view, "takes")
    end

    test "works with 'from' preposition" do
      room = room_fixture()
      %{player: player, view: view} = connect_player(room: room, name: "Alice")

      bag = create_item_in_inventory(player, name: "bag", is_container: true)
      bag_inventory_id = Realms.Game.get_container_inventory_id(bag)
      coin = item_fixture(%{location_id: bag_inventory_id, name: "coin"})

      view
      |> send_command("get coin from bag")
      |> assert_eventual_output("You take coin from bag.")

      assert_item_in_location(coin.id, player.inventory_id)
    end

    test "shows error when multiple containers match search term" do
      room = room_fixture()
      %{player: player, view: view} = connect_player(room: room, name: "Alice")

      create_item_in_inventory(player, name: "small pouch", is_container: true)
      create_item_in_inventory(player, name: "large pouch", is_container: true)

      view
      |> send_command("get coin from pouch")
      |> assert_eventual_output("Multiple items match 'pouch'")
      |> assert_eventual_output("Be more specific")
    end

    test "shows error when multiple items in container match search term" do
      room = room_fixture()
      %{player: player, view: view} = connect_player(room: room, name: "Alice")

      backpack = create_item_in_inventory(player, name: "backpack", is_container: true)
      backpack_inventory_id = Realms.Game.get_container_inventory_id(backpack)

      item_fixture(%{location_id: backpack_inventory_id, name: "red potion"})
      item_fixture(%{location_id: backpack_inventory_id, name: "blue potion"})

      view
      |> send_command("get potion from backpack")
      |> assert_eventual_output("Multiple items in backpack match 'potion'")
      |> assert_eventual_output("Be more specific")
    end
  end
end
