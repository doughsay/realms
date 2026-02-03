defmodule RealmsWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use RealmsWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      use RealmsWeb, :verified_routes

      import Liveness
      import Phoenix.ConnTest
      import Plug.Conn
      import RealmsWeb.ConnCase
      # The default endpoint for testing
      @endpoint RealmsWeb.Endpoint

      # Import conveniences for testing with connections
    end
  end

  setup tags do
    Realms.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc """
  Setup helper that registers and logs in users.

      setup :register_and_log_in_user

  It stores an updated connection and a registered user in the
  test context.
  """
  def register_and_log_in_user(%{conn: conn} = context) do
    user = Realms.AccountsFixtures.user_fixture()
    scope = Realms.Accounts.Scope.for_user(user)

    opts =
      context
      |> Map.take([:token_authenticated_at])
      |> Enum.to_list()

    %{conn: log_in_user(conn, user, opts), user: user, scope: scope}
  end

  @doc """
  Logs the given `user` into the `conn`.

  It returns an updated `conn`.
  """
  def log_in_user(conn, user, opts \\ []) do
    token = Realms.Accounts.generate_user_session_token(user)

    maybe_set_token_authenticated_at(token, opts[:token_authenticated_at])

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, token)
  end

  defp maybe_set_token_authenticated_at(_token, nil), do: nil

  defp maybe_set_token_authenticated_at(token, authenticated_at) do
    Realms.AccountsFixtures.override_token_authenticated_at(token, authenticated_at)
  end

  @doc """
  Setup helper that registers a user, logs them in, and creates a player for them.

      setup :register_and_log_in_user_with_player

  It stores an updated connection, registered user, and player in the test context.
  """
  def register_and_log_in_user_with_player(context) do
    result = register_and_log_in_user(context)
    player = Realms.GameFixtures.player_fixture(result.user)

    result
    |> Map.put(:player, player)
    |> Map.put(:conn, select_player(result.conn, player))
  end

  @doc """
  Sets the player_id in the session to simulate choosing a character.

  Returns an updated conn.
  """
  def select_player(conn, player) do
    Plug.Conn.put_session(conn, :player_id, player.id)
  end

  @doc """
  Creates a second user with a player for multi-player testing.

  Returns a map with :user2, :player2, and :conn2.
  """
  def create_second_player(_context \\ %{}) do
    user2 = Realms.AccountsFixtures.user_fixture()
    player2 = Realms.GameFixtures.player_fixture(user2)

    conn2 =
      Phoenix.ConnTest.build_conn()
      |> log_in_user(user2)
      |> select_player(player2)

    %{user2: user2, player2: player2, conn2: conn2}
  end

  @doc """
  Allows a process to access the SQL sandbox in tests.
  Call this after starting a process that needs database access.
  """
  def allow_sandbox_access(pid) do
    Ecto.Adapters.SQL.Sandbox.allow(Realms.Repo, self(), pid)
  end
end
