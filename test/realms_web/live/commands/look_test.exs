defmodule RealmsWeb.Live.Commands.LookTest do
  use RealmsWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Realms.AccountsFixtures
  import Realms.GameFixtures

  describe "Look Command" do
    setup %{conn: conn} do
      user = user_fixture()
      player = player_fixture(user)

      %{
        conn: log_in_user(conn, user) |> select_player(player),
        user: user,
        player: player,
        room: town_square_fixture()
      }
    end

    test "shows room name & description", %{conn: conn, room: room} do
      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> send_command("look")
      |> assert_eventual_output(room.name)
      |> assert_eventual_output(room.description)
    end

    test "shows other players in the room", %{conn: conn, room: room} do
      %{player: other_player} = create_player(room: room)

      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> send_command("look")
      |> assert_eventual_output(other_player.name)
    end

    test "shows items in the room", %{conn: conn, room: room} do
      item = item_fixture(%{location_id: room.inventory_id})

      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> send_command("look")
      |> assert_eventual_output(item.name)
    end
  end
end
