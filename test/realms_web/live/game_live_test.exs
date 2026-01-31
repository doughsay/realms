defmodule RealmsWeb.GameLiveTest do
  use RealmsWeb.ConnCase
  import Phoenix.LiveViewTest
  alias Realms.Game

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

  describe "mount" do
    test "displays initial room description", %{conn: conn} do
      {:ok, view, html} = live(conn, "/")

      assert html =~ "Town Square"
      assert html =~ "A bustling town square"
      assert has_element?(view, "#game-messages")
      assert has_element?(view, "#command-form")
    end

    test "creates new player with auto-generated name", %{conn: conn} do
      {:ok, _view, html} = live(conn, "/")

      # Should not error and should show game interface
      assert html =~ "Town Square"
      assert html =~ "game-messages"
    end

    test "maintains message history", %{conn: conn} do
      # Connect and execute some commands
      {:ok, view, _html} = live(conn, "/")
      render_submit(view, :execute_command, %{command: %{command: "look"}})
      render_submit(view, :execute_command, %{command: %{command: "say test"}})

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
      html = render_submit(view, :execute_command, %{command: %{command: "north"}})

      # Should show new room description
      assert html =~ "The Rusty Tankard"
      assert html =~ "A cozy tavern"
      # Note: Town Square still appears in history, which is expected
    end

    test "shows error for invalid exit", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      # Try to go east (no exit in that direction)
      html = render_submit(view, :execute_command, %{command: %{command: "east"}})

      assert html =~ "You can&#39;t go that way"
    end

    test "broadcasts departure to old room", %{conn: conn} do
      # Player 1 in town square
      {:ok, view1, _html} = live(conn, "/")

      # Player 2 in town square (new connection)
      conn2 = Phoenix.ConnTest.build_conn()
      {:ok, view2, _html} = live(conn2, "/")

      # Subscribe player 2 to town square to verify broadcast
      # (This is done automatically in mount, just verifying)

      # Player 1 moves north
      render_submit(view1, :execute_command, %{command: %{command: "north"}})

      # Player 2 should see departure message
      html2 = render(view2)
      assert html2 =~ "leaves to the north"
    end

    test "broadcasts arrival to new room", %{conn: conn} do
      # Player 1 starts in tavern
      {:ok, view1, _html} = live(conn, "/")
      render_submit(view1, :execute_command, %{command: %{command: "north"}})

      # Player 2 joins and goes to tavern
      conn2 = Phoenix.ConnTest.build_conn()
      {:ok, view2, _html} = live(conn2, "/")

      # Player 2 moves north to join player 1
      render_submit(view2, :execute_command, %{command: %{command: "north"}})

      # Player 1 should see arrival message
      html1 = render(view1)
      assert html1 =~ "arrives from the south"
    end

    test "moving player doesn't see their own arrival/departure", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      html = render_submit(view, :execute_command, %{command: %{command: "north"}})

      # Should see new room description but not arrival/departure messages
      assert html =~ "The Rusty Tankard"
      refute html =~ "leaves to"
      refute html =~ "arrives from"
    end
  end

  describe "say command" do
    test "broadcasts message to same room", %{conn: conn} do
      {:ok, view1, _html} = live(conn, "/")
      conn2 = Phoenix.ConnTest.build_conn()
      {:ok, view2, _html} = live(conn2, "/")

      # Player 1 says something
      render_submit(view1, :execute_command, %{command: %{command: "say hello world"}})

      # Both players should see the message
      html1 = render(view1)
      html2 = render(view2)

      assert html1 =~ "says: hello world"
      assert html2 =~ "says: hello world"
    end

    test "message is not seen in different room", %{conn: conn} do
      {:ok, view1, _html} = live(conn, "/")

      # Player 2 starts in tavern
      conn2 = Phoenix.ConnTest.build_conn()
      {:ok, view2, _html} = live(conn2, "/")
      render_submit(view2, :execute_command, %{command: %{command: "north"}})

      # Player 1 says something in town square
      render_submit(view1, :execute_command, %{command: %{command: "say testing"}})

      # Player 2 in tavern should not see it
      html2 = render(view2)
      refute html2 =~ "says: testing"
    end

    test "empty say command shows error", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      html = render_submit(view, :execute_command, %{command: %{command: "say"}})

      assert html =~ "Say what?"
    end

    test "say with only whitespace shows error", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      html = render_submit(view, :execute_command, %{command: %{command: "say    "}})

      assert html =~ "Say what?"
    end
  end

  describe "look command" do
    test "shows current room description", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      html = render_submit(view, :execute_command, %{command: %{command: "look"}})

      assert html =~ "Town Square"
      assert html =~ "A bustling town square"
    end

    test "shows other players in room", %{conn: conn} do
      {:ok, _view1, _html} = live(conn, "/")

      # Player 2 joins
      conn2 = Phoenix.ConnTest.build_conn()
      {:ok, view2, _html} = live(conn2, "/")

      html = render_submit(view2, :execute_command, %{command: %{command: "look"}})

      assert html =~ "Also here:"
      assert html =~ "Adventurer_"
    end

    test "doesn't show 'Also here' when alone", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      html = render_submit(view, :execute_command, %{command: %{command: "look"}})

      refute html =~ "Also here:"
    end
  end

  describe "exits command" do
    test "lists available exits", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      html = render_submit(view, :execute_command, %{command: %{command: "exits"}})

      assert html =~ "Obvious exits: north"
    end
  end

  describe "help command" do
    test "shows help text", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      html = render_submit(view, :execute_command, %{command: %{command: "help"}})

      assert html =~ "Available commands"
      assert html =~ "Movement:"
      assert html =~ "say &lt;message&gt;"
    end
  end

  describe "unknown commands" do
    test "shows error for unknown command", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      html = render_submit(view, :execute_command, %{command: %{command: "foobar"}})

      assert html =~ "I don&#39;t understand &#39;foobar&#39;"
      assert html =~ "Type &#39;help&#39; for commands"
    end
  end

  describe "empty commands" do
    test "does nothing for empty command", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      html = render_submit(view, :execute_command, %{command: %{command: ""}})

      # Should not show any error or new message
      # Just verify it doesn't crash
      assert html =~ "Town Square"
    end
  end

  describe "command input" do
    test "clears input after command execution", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/")

      render_submit(view, :execute_command, %{command: %{command: "look"}})

      # Form should be cleared
      assert has_element?(view, "input[value='']")
    end
  end
end
