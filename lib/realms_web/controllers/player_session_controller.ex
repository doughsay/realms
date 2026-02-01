defmodule RealmsWeb.PlayerSessionController do
  use RealmsWeb, :controller

  alias Realms.Game

  def play_as(conn, %{"id" => player_id}) do
    user = conn.assigns.current_scope.user

    # Verify the player belongs to the current user
    case Game.get_player(player_id) do
      nil ->
        conn
        |> put_flash(:error, "Player not found")
        |> redirect(to: ~p"/players")

      player ->
        if player.user_id == user.id do
          conn
          |> put_session(:player_id, player.id)
          |> redirect(to: ~p"/")
        else
          conn
          |> put_flash(:error, "You can only play as your own characters")
          |> redirect(to: ~p"/players")
        end
    end
  end
end
