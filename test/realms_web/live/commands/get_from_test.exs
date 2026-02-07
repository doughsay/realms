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
      |> assert_eventual_output("You don't see 'banana' in the chest.")
    end

    test "shows error when container not found" do
      room = room_fixture()
      %{view: view} = connect_player(room: room, name: "Alice")

      view
      |> send_command("get apple from chest")
      |> assert_eventual_output("You're not holding 'chest'.")
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
      assert_eventual_output(player2_view, "Alice takes something from chest.")
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

    test "uses first container alphabetically when multiple containers match" do
      room = room_fixture()
      %{player: player, view: view} = connect_player(room: room, name: "Alice")

      _small_pouch = create_item_in_inventory(player, name: "small pouch", is_container: true)
      large_pouch = create_item_in_inventory(player, name: "large pouch", is_container: true)

      # Put a coin in the large pouch
      large_pouch_inv_id = Realms.Game.get_container_inventory_id(large_pouch)
      coin = item_fixture(%{location_id: large_pouch_inv_id, name: "coin"})

      view
      |> send_command("get coin from pouch")
      |> assert_eventual_output("You take coin from large pouch.")

      assert_item_in_location(coin.id, player.inventory_id)
    end

    test "gets first item alphabetically when multiple items in container match" do
      room = room_fixture()
      %{player: player, view: view} = connect_player(room: room, name: "Alice")

      backpack = create_item_in_inventory(player, name: "backpack", is_container: true)
      backpack_inventory_id = Realms.Game.get_container_inventory_id(backpack)

      red_potion = item_fixture(%{location_id: backpack_inventory_id, name: "red potion"})
      blue_potion = item_fixture(%{location_id: backpack_inventory_id, name: "blue potion"})

      view
      |> send_command("get potion from backpack")
      |> assert_eventual_output("You take blue potion from backpack.")

      # Verify blue potion is in inventory, red potion still in backpack
      assert_item_in_location(blue_potion.id, player.inventory_id)
      assert_item_in_location(red_potion.id, backpack_inventory_id)
    end
  end
end
