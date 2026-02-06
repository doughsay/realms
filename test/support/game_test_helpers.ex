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
  def assert_eventual_output(view, expected_content, timeout \\ 100) do
    interval = 20
    tries = div(timeout, interval)

    assert eventually(
             fn ->
               rendered = render(view)

               text_content =
                 rendered
                 |> LazyHTML.from_fragment()
                 |> LazyHTML.text()

               text_content =~ expected_content
             end,
             tries,
             interval
           )

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
  Returns `%{user: user, player: player, view: view}`.
  """
  def connect_player(user, player) do
    Realms.Game.set_player_status(player.id, :online)

    {:ok, view, _html} =
      Phoenix.ConnTest.build_conn()
      |> log_in_user(user)
      |> select_player(player)
      |> live(~p"/")

    %{user: user, player: player, view: view}
  end

  @doc """
  Connects a player to the game LiveView with auto-creation.

  Options:
    - :room (required) - The room to place the player in
    - :name (optional) - Player name, defaults to unique generated name
    - :user (optional) - Use existing user instead of creating new one
    - :player (optional) - Use existing player instead of creating new one
    - :player_attrs (optional) - Additional attributes for player_fixture/2

  Returns: `%{user: user, player: player, view: view}`

  ## Examples

      %{view: view} = connect_player(room: room)
      %{player: player, view: view} = connect_player(room: room, name: "Bob")
      %{view: view} = connect_player(user: user, room: room)
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

  Returns: List of `%{user: user, player: player, view: view}` maps

  ## Examples

      # Just get views
      [%{view: view1}, %{view: view2}] = connect_players([
        [room: start_room],
        [room: dest_room, name: "Bob"]
      ])

      # Get specific fields
      [%{player: p1, view: v1}, %{player: p2, view: v2}] = connect_players([...])
  """
  def connect_players(players_opts) when is_list(players_opts) do
    Enum.map(players_opts, &connect_player/1)
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

  @doc """
  Creates an item in a room's inventory.

  Options:
    - :name (optional) - Item name, defaults to unique generated name
    - :description (optional) - Item description
    - :is_container (optional) - Make it a container, default false
    - Other item_fixture attributes

  Returns: item struct

  ## Examples

      item = create_item_in_room(room, name: "apple")
      container = create_item_in_room(room, name: "backpack", is_container: true)
  """
  def create_item_in_room(room, opts \\ []) do
    is_container = Keyword.get(opts, :is_container, false)
    opts = Keyword.delete(opts, :is_container)

    attrs =
      opts
      |> Map.new()
      |> Map.put(:location_id, room.inventory_id)
      |> Map.put_new(:name, "item_#{System.unique_integer([:positive])}")
      |> Map.put_new(:description, "A simple item.")

    {:ok, item} = Realms.Game.create_item(attrs, has_inventory: is_container)
    item
  end

  @doc """
  Creates an item in a player's inventory.

  Options: Same as create_item_in_room

  Returns: item struct

  ## Examples

      item = create_item_in_inventory(player, name: "sword")
  """
  def create_item_in_inventory(player, opts \\ []) do
    is_container = Keyword.get(opts, :is_container, false)
    opts = Keyword.delete(opts, :is_container)

    attrs =
      opts
      |> Map.new()
      |> Map.put(:location_id, player.inventory_id)
      |> Map.put_new(:name, "item_#{System.unique_integer([:positive])}")
      |> Map.put_new(:description, "A simple item.")

    {:ok, item} = Realms.Game.create_item(attrs, has_inventory: is_container)
    item
  end

  @doc """
  Asserts that text does NOT appear in view output.

  Waits for the timeout period to let any async operations complete,
  then asserts the text is not present.

  Uses LazyHTML to extract text content, matching across multiple HTML elements.

  Returns: view (for chaining)

  ## Examples

      view
      |> send_command("say hello")
      |> assert_no_output("hello")  # Sender shouldn't see own message echoed
  """
  def assert_no_output(view, text, timeout \\ 100) do
    Process.sleep(timeout)

    rendered = render(view)

    text_content =
      rendered
      |> LazyHTML.from_fragment()
      |> LazyHTML.text()

    refute text_content =~ text,
           "Expected text '#{text}' to NOT be present, but it was found in output"

    view
  end

  @doc """
  Verifies an item is in the expected location by querying fresh from DB.

  Returns: item struct

  ## Examples

      assert_item_in_location(apple.id, player.inventory_id)
      assert_item_in_location(sword.id, backpack.inventory_id)
  """
  def assert_item_in_location(item_id, expected_location_id) do
    item = Realms.Repo.get!(Realms.Game.Item, item_id)

    assert item.location_id == expected_location_id, """
    Expected item #{item_id} to be in location #{expected_location_id},
    but found it in location #{item.location_id}
    """

    item
  end
end
