defmodule RealmsWeb.Commands.PutTest do
  use RealmsWeb.ConnCase, async: false

  import Realms.GameFixtures
  import RealmsWeb.GameTestHelpers

  describe "put command" do
    test "puts item from inventory into container in inventory" do
      room = room_fixture()
      %{player: player, view: view} = connect_player(room: room, name: "Alice")

      apple = create_item_in_inventory(player, name: "apple")
      backpack = create_item_in_inventory(player, name: "backpack", is_container: true)

      view
      |> send_command("put apple in backpack")
      |> assert_eventual_output("You put apple into backpack.")

      # Verify apple is now inside backpack's inventory
      backpack_inventory_id = Realms.Game.get_container_inventory_id(backpack)
      assert_item_in_location(apple.id, backpack_inventory_id)
    end

    test "shows error when item not found" do
      room = room_fixture()
      %{player: player, view: view} = connect_player(room: room, name: "Alice")

      create_item_in_inventory(player, name: "backpack", is_container: true)

      view
      |> send_command("put banana in backpack")
      |> assert_eventual_output("You aren't holding 'banana'.")
    end

    test "shows error when container not found" do
      room = room_fixture()
      %{player: player, view: view} = connect_player(room: room, name: "Alice")

      create_item_in_inventory(player, name: "apple")

      view
      |> send_command("put apple in chest")
      |> assert_eventual_output("You aren't holding 'chest'.")
    end

    test "shows error when target is not a container" do
      room = room_fixture()
      %{player: player, view: view} = connect_player(room: room, name: "Alice")

      create_item_in_inventory(player, name: "apple")
      create_item_in_inventory(player, name: "sword", is_container: false)

      view
      |> send_command("put apple in sword")
      |> assert_eventual_output("doesn't seem to hold")
    end

    test "prevents putting container into itself" do
      room = room_fixture()
      %{player: player, view: view} = connect_player(room: room, name: "Alice")

      create_item_in_inventory(player, name: "backpack", is_container: true)

      view
      |> send_command("put backpack in backpack")
      |> assert_eventual_output("can't put an item inside itself")
    end

    test "players in room see put action" do
      room = room_fixture()
      %{player: player1} = create_player(room: room, name: "Alice")

      [%{view: player1_view}, %{view: player2_view}] =
        connect_players([
          [room: room, player: player1],
          [room: room, name: "Bob"]
        ])

      create_item_in_inventory(player1, name: "gem")
      create_item_in_inventory(player1, name: "pouch", is_container: true)

      send_command(player1_view, "put gem in pouch")

      # Observer should see the action
      assert_eventual_output(player2_view, "Alice puts gem into pouch.")
    end

    test "puts first item alphabetically when multiple items match" do
      room = room_fixture()
      %{player: player, view: view} = connect_player(room: room, name: "Alice")

      red_gem = create_item_in_inventory(player, name: "red gem")
      blue_gem = create_item_in_inventory(player, name: "blue gem")
      backpack = create_item_in_inventory(player, name: "backpack", is_container: true)
      backpack_inv_id = Realms.Game.get_container_inventory_id(backpack)

      view
      |> send_command("put gem in backpack")
      |> assert_eventual_output("You put blue gem into backpack.")

      # Verify blue gem is in backpack, red gem still in inventory
      assert_item_in_location(blue_gem.id, backpack_inv_id)
      assert_item_in_location(red_gem.id, player.inventory_id)
    end

    test "uses first container alphabetically when multiple containers match" do
      room = room_fixture()
      %{player: player, view: view} = connect_player(room: room, name: "Alice")

      apple = create_item_in_inventory(player, name: "apple")
      _small_pouch = create_item_in_inventory(player, name: "small pouch", is_container: true)
      large_pouch = create_item_in_inventory(player, name: "large pouch", is_container: true)
      large_pouch_inv_id = Realms.Game.get_container_inventory_id(large_pouch)

      view
      |> send_command("put apple in pouch")
      |> assert_eventual_output("You put apple into large pouch.")

      assert_item_in_location(apple.id, large_pouch_inv_id)
    end
  end
end
