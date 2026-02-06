defmodule RealmsWeb.Live.Commands.MoveTest do
  use RealmsWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Realms.AccountsFixtures
  import Realms.GameFixtures

  describe "Move Command" do
    setup %{conn: conn} do
      user = user_fixture()
      player = player_fixture(user)
      start_room = town_square_fixture()

      %{
        conn: log_in_user(conn, user) |> select_player(player),
        user: user,
        player: player,
        start_room: start_room
      }
    end

    test "moves successfully to a connected room", %{conn: conn, start_room: start_room} do
      destination_room = room_fixture(%{name: "The Void", description: "Empty space."})
      exit_fixture(start_room, destination_room, "north")

      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> send_command("north")
      |> assert_eventual_output("The Void")
      |> assert_eventual_output("Empty space")
    end

    test "fails to move in invalid direction", %{player: player, user: user} do
      %{view: view} = connect_player(user, player)

      view
      |> send_command("south")
      |> assert_eventual_output("You can't go that way")
    end

    test "notifies other players of movement", %{
      start_room: start_room,
      user: user,
      player: player
    } do
      destination_room = room_fixture()
      exit_fixture(start_room, destination_room, "east")

      %{view: view} = connect_player(user, player)

      [%{view: observer_view}, %{view: dest_observer_view}] =
        connect_players([
          [room: start_room],
          [room: destination_room]
        ])

      send_command(view, "east")

      # observer in old room sees departure
      assert_eventual_output(observer_view, "goes east")

      # observer in new room sees arrival
      assert_eventual_output(dest_observer_view, "arrives from the west")
    end
  end
end
