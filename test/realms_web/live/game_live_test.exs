defmodule RealmsWeb.GameLiveTest do
  use RealmsWeb.ConnCase
  import Phoenix.LiveViewTest
  alias Realms.Game

  # Helper to execute command and wait for GenServer processing
  defp execute_command_and_wait(view, command) do
    render_submit(view, :execute_command, %{command: %{command: command}})
    # Small delay for async GenServer processing
    Process.sleep(20)
  end

  setup do
    # Ensure the database is seeded with basic rooms
    # Clean up any existing data
    Realms.Repo.delete_all(Realms.Game.Exit)
    Realms.Repo.delete_all(Realms.Game.Room)
    Realms.Repo.delete_all(Realms.Game.Player)

    # Create test rooms
    {:ok, town_square} =
      Game.create_room(%{
        name: "Town Square",
        description: "A bustling town square with a fountain in the center."
      })

    {:ok, tavern} =
      Game.create_room(%{
        name: "The Rusty Tankard",
        description: "A cozy tavern with a roaring fireplace."
      })

    # Create bidirectional exit
    {:ok, _} = Game.create_bidirectional_exit(town_square.id, tavern.id, "north", "south")

    {:ok, town_square: town_square, tavern: tavern}
  end

  setup :register_and_log_in_user_with_player

  describe "mount" do
    test "displays initial room description", %{conn: conn} do
      {:ok, view, html} = live(conn, "/")

      assert html =~ "Town Square"
      assert html =~ "A bustling town square"
      assert has_element?(view, "#game-messages")
      assert has_element?(view, "#command-form")
    end

    test "loads player and shows game interface", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      # Should not error and should show game interface
      assert html =~ "Town Square"
      assert html =~ "game-messages"
    end

    test "maintains message history", %{conn: conn} do
      # Connect and execute some commands
      {:ok, view, _html} = live(conn, "/")
      execute_command_and_wait(view, "look")
      execute_command_and_wait(view, "say test")

      # Get current HTML
      html = render(view)

      # Should show both messages in history
      assert html =~ "Town Square"
      assert html =~ "says: test"
    end
  end

  describe "movement commands" do
    test "successfully moves to a new room", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Move north
      execute_command_and_wait(view, "north")
      html = render(view)

      # Should show new room description
      assert html =~ "The Rusty Tankard"
      assert html =~ "A cozy tavern"
      # Note: Town Square still appears in history, which is expected
    end

    test "shows error for invalid exit", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Try to go east (no exit in that direction)
      execute_command_and_wait(view, "east")
      html = render(view)

      assert html =~ "You can&#39;t go that way"
    end

    test "broadcasts departure to old room", %{conn: conn} do
      # Player 1 in town square
      {:ok, view1, _html} = live(conn, "/")

      # Player 2 in town square (new connection)
      %{conn2: conn2} = create_second_player()
      {:ok, view2, _html} = live(conn2, "/")

      # Player 1 moves north
      execute_command_and_wait(view1, "north")

      # Player 2 should see departure message
      html2 = render(view2)
      assert html2 =~ "leaves to the north"
    end

    test "broadcasts arrival to new room", %{conn: conn} do
      # Player 1 starts in tavern
      {:ok, view1, _html} = live(conn, "/")
      execute_command_and_wait(view1, "north")

      # Player 2 joins and goes to tavern
      %{conn2: conn2} = create_second_player()
      {:ok, view2, _html} = live(conn2, "/")

      # Player 2 moves north to join player 1
      execute_command_and_wait(view2, "north")

      # Player 1 should see arrival message
      html1 = render(view1)
      assert html1 =~ "arrives from the south"
    end

    test "moving player doesn't see their own arrival/departure", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      execute_command_and_wait(view, "north")
      html = render(view)

      # Should see new room description but not arrival/departure messages
      assert html =~ "The Rusty Tankard"
      refute html =~ "leaves to"
      refute html =~ "arrives from"
    end
  end

  describe "say command" do
    test "broadcasts message to same room", %{conn: conn} do
      {:ok, view1, _html} = live(conn, "/")
      %{conn2: conn2} = create_second_player()
      {:ok, view2, _html} = live(conn2, "/")

      # Player 1 says something
      execute_command_and_wait(view1, "say hello world")

      # Both players should see the message
      html1 = render(view1)
      html2 = render(view2)

      assert html1 =~ "says: hello world"
      assert html2 =~ "says: hello world"
    end

    test "message is not seen in different room", %{conn: conn} do
      {:ok, view1, _html} = live(conn, "/")

      # Player 2 starts in tavern
      %{conn2: conn2} = create_second_player()
      {:ok, view2, _html} = live(conn2, "/")
      execute_command_and_wait(view2, "north")

      # Player 1 says something in town square
      execute_command_and_wait(view1, "say testing")

      # Player 2 in tavern should not see it
      html2 = render(view2)
      refute html2 =~ "says: testing"
    end

    test "empty say command shows error", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      execute_command_and_wait(view, "say")
      html = render(view)

      assert html =~ "Say what?"
    end

    test "say with only whitespace shows error", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      execute_command_and_wait(view, "say    ")
      html = render(view)

      assert html =~ "Say what?"
    end
  end

  describe "look command" do
    test "shows current room description", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      execute_command_and_wait(view, "look")
      html = render(view)

      assert html =~ "Town Square"
      assert html =~ "A bustling town square"
    end

    test "shows other players in room", %{conn: conn, player: player} do
      {:ok, _view1, _html} = live(conn, "/")

      # Player 2 joins
      %{conn2: conn2} = create_second_player()
      {:ok, view2, _html} = live(conn2, "/")

      execute_command_and_wait(view2, "look")
      html = render(view2)

      assert html =~ "Also here:"
      assert html =~ player.name
    end

    test "doesn't show 'Also here' when alone", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      execute_command_and_wait(view, "look")
      html = render(view)

      refute html =~ "Also here:"
    end
  end

  describe "exits command" do
    test "lists available exits", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      execute_command_and_wait(view, "exits")
      html = render(view)

      assert html =~ "Obvious exits: north"
    end
  end

  describe "help command" do
    test "shows help text", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      execute_command_and_wait(view, "help")
      html = render(view)

      assert html =~ "Available commands"
      assert html =~ "Movement:"
      assert html =~ "say &lt;message&gt;"
    end
  end

  describe "unknown commands" do
    test "shows error for unknown command", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      execute_command_and_wait(view, "foobar")
      html = render(view)

      assert html =~ "I don&#39;t understand &#39;foobar&#39;"
      assert html =~ "Type &#39;help&#39; for commands"
    end
  end

  describe "empty commands" do
    test "does nothing for empty command", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      execute_command_and_wait(view, "")
      html = render(view)

      # Should not show any error or new message
      # Just verify it doesn't crash
      assert html =~ "Town Square"
    end
  end

  describe "command input" do
    test "clears input after command execution", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      execute_command_and_wait(view, "look")

      # Form should be cleared
      assert has_element?(view, "input[value='']")
    end
  end

  describe "cleanup mechanisms" do
    test "view is removed from Player GenServer when LiveView stops", %{
      conn: conn,
      player: player
    } do
      {:ok, view, _html} = live(conn, "/")

      # Get the Player GenServer and verify view is registered
      [{genserver_pid, _}] = Registry.lookup(Realms.PlayerRegistry, player.id)
      state = :sys.get_state(genserver_pid)
      assert MapSet.size(state.connected_views) == 1

      # Stop the LiveView (this triggers :DOWN message)
      GenServer.stop(view.pid)
      Process.sleep(20)

      # View should be cleaned up via :DOWN message
      state = :sys.get_state(genserver_pid)
      assert MapSet.size(state.connected_views) == 0
    end

    test "multiple tabs share same Player GenServer", %{conn: conn, player: player} do
      {:ok, view1, _html} = live(conn, "/")
      {:ok, view2, _html} = live(conn, "/")

      # Both views should be connected to the same GenServer
      [{genserver_pid, _}] = Registry.lookup(Realms.PlayerRegistry, player.id)
      state = :sys.get_state(genserver_pid)
      assert MapSet.size(state.connected_views) == 2

      # Stop one view
      GenServer.stop(view1.pid)
      Process.sleep(20)

      # Other view should still be connected
      state = :sys.get_state(genserver_pid)
      assert MapSet.size(state.connected_views) == 1

      # GenServer should still be alive
      assert Process.alive?(genserver_pid)
      # Keep view2 alive to prevent warnings
      assert is_pid(view2.pid)
    end
  end

  describe "offline message capture" do
    test "Player GenServer captures messages while LiveView is disconnected", %{
      conn: conn,
      player: player
    } do
      # Player 1 connects
      {:ok, view1, _html} = live(conn, "/")

      # Player 2 connects
      %{conn2: conn2, player2: player2} = create_second_player()
      {:ok, view2, _html} = live(conn2, "/")

      # Verify both Player GenServers exist
      [{player1_genserver, _}] = Registry.lookup(Realms.PlayerRegistry, player.id)
      [{_player2_genserver, _}] = Registry.lookup(Realms.PlayerRegistry, player2.id)

      # Player 1 disconnects (LiveView stops, but GenServer stays alive)
      GenServer.stop(view1.pid)
      Process.sleep(20)

      # Verify Player 1's GenServer is still alive (no views, but hasn't timed out yet)
      assert Process.alive?(player1_genserver)

      # Player 2 says something while Player 1 is disconnected
      execute_command_and_wait(view2, "say hello while you were gone")

      # Give time for PubSub to deliver to Player 1's GenServer
      Process.sleep(50)

      # Verify Player 1's GenServer captured the message (even with no views)
      player1_state = :sys.get_state(player1_genserver)

      assert Enum.any?(player1_state.message_history, fn msg ->
               msg.content =~ "hello while you were gone"
             end)

      # Player 1 reconnects with a new LiveView
      {:ok, view1_new, _html} = live(conn, "/")

      # The reconnected view should show the missed message
      html = render(view1_new)
      assert html =~ "hello while you were gone"
    end

    test "missed messages persist across reconnection", %{conn: conn} do
      # Player 1 connects and gets initial history
      {:ok, view1, _html} = live(conn, "/")
      initial_html = render(view1)

      # Player 2 joins
      %{conn2: conn2} = create_second_player()
      {:ok, view2, _html} = live(conn2, "/")

      # Player 1 disconnects
      GenServer.stop(view1.pid)
      Process.sleep(20)

      # Player 2 sends multiple messages while Player 1 is offline
      execute_command_and_wait(view2, "say message 1")
      execute_command_and_wait(view2, "say message 2")
      execute_command_and_wait(view2, "say message 3")

      # Give time for messages to be processed
      Process.sleep(50)

      # Player 1 reconnects
      {:ok, view1_new, _html} = live(conn, "/")
      reconnect_html = render(view1_new)

      # Should see all missed messages
      assert reconnect_html =~ "message 1"
      assert reconnect_html =~ "message 2"
      assert reconnect_html =~ "message 3"

      # Initial view didn't have these messages
      refute initial_html =~ "message 1"
    end
  end
end
