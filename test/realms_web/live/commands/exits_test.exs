defmodule RealmsWeb.Commands.ExitsTest do
  use RealmsWeb.ConnCase, async: false

  import Realms.GameFixtures
  import RealmsWeb.GameTestHelpers

  describe "exits command" do
    test "lists all exits from current room" do
      room = room_fixture()
      north_room = room_fixture()
      south_room = room_fixture()
      east_room = room_fixture()

      exit_fixture(room, north_room, "north")
      exit_fixture(room, south_room, "south")
      exit_fixture(room, east_room, "east")

      %{view: view} = connect_player(room: room, name: "Alice")

      view
      |> send_command("exits")
      |> assert_eventual_output("north")
      |> assert_eventual_output("south")
      |> assert_eventual_output("east")
    end

    test "shows message when no exits available" do
      room = room_fixture()
      %{view: view} = connect_player(room: room, name: "Alice")

      view
      |> send_command("exits")
      |> assert_eventual_output("none")
    end

    test "does not show exits from other rooms" do
      room1 = room_fixture()
      room2 = room_fixture()
      room3 = room_fixture()

      exit_fixture(room1, room3, "north")
      exit_fixture(room2, room3, "south")

      %{view: view} = connect_player(room: room1, name: "Alice")

      view
      |> send_command("exits")
      |> assert_eventual_output("north")
      |> assert_no_output("south")
    end

    test "shows bidirectional exits" do
      room1 = room_fixture()
      room2 = room_fixture()

      exit_fixture(room1, room2, "north")
      exit_fixture(room2, room1, "south")

      %{view: view} = connect_player(room: room1, name: "Alice")

      view
      |> send_command("exits")
      |> assert_eventual_output("north")
      |> assert_no_output("south")
    end
  end
end
