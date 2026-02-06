defmodule RealmsWeb.Commands.ExamineTest do
  use RealmsWeb.ConnCase, async: false

  import Realms.GameFixtures
  import RealmsWeb.GameTestHelpers

  describe "examine command" do
    test "shows item description from room" do
      room = room_fixture()
      %{view: view} = connect_player(room: room, name: "Alice")

      create_item_in_room(room, name: "sword", description: "A gleaming steel sword")

      view
      |> send_command("examine sword")
      |> assert_eventual_output("gleaming steel sword")
    end

    test "shows item description from inventory" do
      room = room_fixture()
      %{player: player, view: view} = connect_player(room: room, name: "Alice")

      create_item_in_inventory(player, name: "amulet", description: "A mysterious glowing amulet")

      view
      |> send_command("examine amulet")
      |> assert_eventual_output("mysterious glowing amulet")
    end

    test "shows error when item not found" do
      room = room_fixture()
      %{view: view} = connect_player(room: room, name: "Alice")

      view
      |> send_command("examine unicorn")
      |> assert_eventual_output("don't see")
      |> assert_eventual_output("unicorn")
    end

    test "works with 'x' abbreviation" do
      room = room_fixture()
      %{view: view} = connect_player(room: room, name: "Alice")

      create_item_in_room(room, name: "book", description: "An ancient tome")

      view
      |> send_command("x book")
      |> assert_eventual_output("ancient tome")
    end

    test "shows container contents when examining container" do
      room = room_fixture()
      %{view: view} = connect_player(room: room, name: "Alice")

      backpack = create_item_in_room(room, name: "backpack", is_container: true)
      backpack_inventory_id = Realms.Game.get_container_inventory_id(backpack)

      # Create items inside the backpack
      item_fixture(%{location_id: backpack_inventory_id, name: "apple"})
      item_fixture(%{location_id: backpack_inventory_id, name: "rope"})

      view
      |> send_command("examine backpack")
      |> assert_eventual_output("apple")
      |> assert_eventual_output("rope")
    end

    test "shows empty message for empty container" do
      room = room_fixture()
      %{view: view} = connect_player(room: room, name: "Alice")

      create_item_in_room(room, name: "box", is_container: true)

      view
      |> send_command("examine box")
      |> assert_eventual_output("It is empty")
    end
  end
end
