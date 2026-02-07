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
      |> assert_eventual_output("aren't holding")
      |> assert_eventual_output("banana")
    end

    test "shows error when container not found" do
      room = room_fixture()
      %{player: player, view: view} = connect_player(room: room, name: "Alice")

      create_item_in_inventory(player, name: "apple")

      view
      |> send_command("put apple in chest")
      |> assert_eventual_output("aren't holding")
      |> assert_eventual_output("chest")
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
      assert_eventual_output(player2_view, "Alice")
      assert_eventual_output(player2_view, "gem")
    end

    test "shows error when multiple items match search term" do
      room = room_fixture()
      %{player: player, view: view} = connect_player(room: room, name: "Alice")

      create_item_in_inventory(player, name: "red gem")
      create_item_in_inventory(player, name: "blue gem")
      create_item_in_inventory(player, name: "backpack", is_container: true)

      view
      |> send_command("put gem in backpack")
      |> assert_eventual_output("Multiple items match 'gem'")
      |> assert_eventual_output("Be more specific")
    end

    test "shows error when multiple containers match search term" do
      room = room_fixture()
      %{player: player, view: view} = connect_player(room: room, name: "Alice")

      create_item_in_inventory(player, name: "apple")
      create_item_in_inventory(player, name: "small pouch", is_container: true)
      create_item_in_inventory(player, name: "large pouch", is_container: true)

      view
      |> send_command("put apple in pouch")
      |> assert_eventual_output("Multiple items match 'pouch'")
      |> assert_eventual_output("Be more specific")
    end
  end
end
