defmodule RealmsWeb.PlayerSession do
  @moduledoc """
  Plug that ensures each user has a persistent player_id stored in their session cookie.
  This works for both HTTP requests and LiveView connections.
  """
  import Plug.Conn

  @behaviour Plug

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_session(conn, :player_id) do
      nil ->
        player_id = generate_player_id()
        put_session(conn, :player_id, player_id)

      _player_id ->
        conn
    end
  end

  @doc """
  on_mount hook to assign player_id from session to socket
  """
  def on_mount(:default, _params, session, socket) do
    player_id = Map.get(session, "player_id")
    {:cont, Phoenix.Component.assign(socket, :player_id, player_id)}
  end

  defp generate_player_id do
    Ecto.UUID.generate()
  end
end
