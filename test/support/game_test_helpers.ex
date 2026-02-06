defmodule RealmsWeb.GameTestHelpers do
  @moduledoc """
  Helpers for Game LiveView integration tests.
  """

  use RealmsWeb, :verified_routes

  import ExUnit.Assertions
  import Liveness
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  import Realms.AccountsFixtures
  import Realms.GameFixtures
  import RealmsWeb.ConnCase, only: [log_in_user: 2]

  @doc """
  Sends a command via the game form.
  """
  def send_command(view, command) do
    view
    |> form("#command-form", command: %{command: command})
    |> render_submit()

    view
  end

  @doc """
  Asserts that the view eventually contains the expected content.
  """
  def assert_eventual_output(view, expected_content, timeout \\ 1000) do
    assert eventually(fn -> render(view) =~ html_escape(expected_content) end, timeout)
    view
  end

  @doc """
  Escapes a string for safe HTML rendering.
  """
  def html_escape(string) do
    string |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
  end

  @doc """
  Sets the player_id in the session to simulate choosing a character.

  Returns an updated conn.
  """
  def select_player(conn, player) do
    Plug.Conn.put_session(conn, :player_id, player.id)
  end

  @doc """
  Connects a player to the game LiveView.
  Returns `{:ok, view, html}`.
  """
  def connect_player(user, player) do
    Phoenix.ConnTest.build_conn()
    |> log_in_user(user)
    |> select_player(player)
    |> live(~p"/")
  end

  @doc """
  Connects a player to the game LiveView with auto-creation.

  Options:
    - :room (required) - The room to place the player in
    - :name (optional) - Player name, defaults to unique generated name
    - :user (optional) - Use existing user instead of creating new one
    - :player (optional) - Use existing player instead of creating new one
    - :player_attrs (optional) - Additional attributes for player_fixture/2

  Returns: {:ok, view, html} just like the 2-arg version

  ## Examples

      {:ok, view, _} = connect_player(room: room)
      {:ok, view, _} = connect_player(room: room, name: "Bob")
      {:ok, view, _} = connect_player(user: user, room: room)
  """
  def connect_player(opts) when is_list(opts) do
    room = Keyword.fetch!(opts, :room)
    user = Keyword.get(opts, :user) || user_fixture()

    player =
      case Keyword.fetch(opts, :player) do
        {:ok, player} ->
          player

        :error ->
          player_attrs =
            opts
            |> Keyword.get(:player_attrs, %{})
            |> Map.put(:current_room_id, room.id)
            |> then(fn attrs ->
              case Keyword.fetch(opts, :name) do
                {:ok, name} -> Map.put(attrs, :name, name)
                :error -> attrs
              end
            end)

          player_fixture(user, player_attrs)
      end

    connect_player(user, player)
  end

  @doc """
  Connect multiple players to the game LiveView.

  Takes a list of option keyword lists (same format as connect_player/1).

  Returns: List of views (without html, for cleaner destructuring)

  ## Examples

      [view1, view2] = connect_players([
        [room: start_room],
        [room: dest_room, name: "Bob"]
      ])
  """
  def connect_players(players_opts) when is_list(players_opts) do
    Enum.map(players_opts, fn opts ->
      {:ok, view, _html} = connect_player(opts)
      view
    end)
  end

  @doc """
  Create a user and player in a specific room without connecting to LiveView.

  Useful when you need the entities but don't need the view yet, or when
  you want to connect them later with custom logic.

  Options: Same as connect_player/1

  Returns: %{user: user, player: player}

  ## Examples

      %{user: user, player: player} = create_player(room: some_room)
      # ... do other setup ...
      {:ok, view, _} = connect_player(user, player)
  """
  def create_player(opts) do
    room = Keyword.fetch!(opts, :room)
    user = Keyword.get(opts, :user) || user_fixture()

    player_attrs =
      opts
      |> Keyword.get(:player_attrs, %{})
      |> Map.put(:current_room_id, room.id)
      |> then(fn attrs ->
        case Keyword.fetch(opts, :name) do
          {:ok, name} -> Map.put(attrs, :name, name)
          :error -> attrs
        end
      end)

    player = player_fixture(user, player_attrs)
    %{user: user, player: player}
  end

  @doc """
  Debug helper to print all messages in the view.

  Very rough, but you can sorta read the message content.
  """
  def debug_print_message(view) do
    messages =
      view
      |> element("#messages")
      |> render()
      |> LazyHTML.from_fragment()
      |> LazyHTML.query("#messages > div > div span")
      |> Enum.map_join("\n", &LazyHTML.text/1)

    IO.puts(messages)
  end
end
