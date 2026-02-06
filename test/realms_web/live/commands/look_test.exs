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
  end
end
