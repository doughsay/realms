defmodule RealmsWeb.PlayerManagementLiveTest do
  use RealmsWeb.ConnCase
  import Phoenix.LiveViewTest

  alias Realms.Accounts

  describe "PlayerManagementLive" do
    setup %{conn: conn} do
      # Clean up and create test room
      Realms.Repo.delete_all(Realms.Game.Exit)
      Realms.Repo.delete_all(Realms.Game.Room)
      Realms.Repo.delete_all(Realms.Game.Player)

      {:ok, _town_square} =
        Realms.Game.create_room(%{
          name: "Town Square",
          description: "A bustling town square."
        })

      user = Accounts.register_user(%{email: "test@example.com"}) |> elem(1)
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
