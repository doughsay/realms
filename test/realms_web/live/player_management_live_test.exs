defmodule RealmsWeb.PlayerManagementLiveTest do
  use RealmsWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Realms.AccountsFixtures
  import Realms.GameFixtures

  describe "PlayerManagementLive" do
    setup %{conn: conn} do
      town_square_fixture()

      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "renders the player management page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/players")
      assert html =~ "Your Characters"
    end

    test "allows creating a new player", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/players")

      view
      |> form("#player-form", player: %{name: "Test Character"})
      |> render_submit()

      assert render(view) =~ "Test Character"
      assert render(view) =~ "Player created successfully"
    end

    test "allows deleting a player", %{conn: conn, user: user} do
      # Create a player first
      {:ok, view, _html} = live(conn, ~p"/players")

      view
      |> form("#player-form", player: %{name: "Test Character"})
      |> render_submit()

      # Now delete it
      players = Realms.Game.list_players_for_user(user.id)
      player = List.first(players)

      view
      |> element("button[phx-click='delete'][phx-value-id='#{player.id}']")
      |> render_click()

      refute render(view) =~ "Test Character"
      assert render(view) =~ "Player deleted successfully"
    end
  end
end
