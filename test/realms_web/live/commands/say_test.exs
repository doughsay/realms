defmodule RealmsWeb.Commands.SayTest do
  use RealmsWeb.ConnCase, async: false

  import Realms.GameFixtures
  import RealmsWeb.GameTestHelpers

  describe "say command" do
    test "broadcasts message to all players in the room" do
      room = room_fixture()

      [%{view: speaker}, %{view: listener1}, %{view: listener2}] =
        connect_players([
          [room: room, name: "Alice"],
          [room: room, name: "Bob"],
          [room: room, name: "Carol"]
        ])

      send_command(speaker, "say Hello everyone!")

      # Listeners should see the message with speaker's name
      assert_eventual_output(listener1, "Alice says: Hello everyone!")
      assert_eventual_output(listener2, "Alice says: Hello everyone!")
    end

    test "does not broadcast to players in different rooms" do
      room1 = room_fixture()
      room2 = room_fixture()

      [%{view: speaker}, %{view: listener_same_room}, %{view: listener_other_room}] =
        connect_players([
          [room: room1, name: "Alice"],
          [room: room1, name: "Bob"],
          [room: room2, name: "Carol"]
        ])

      send_command(speaker, "say Secret message")

      # Same room listener should see it
      assert_eventual_output(listener_same_room, "Alice says: Secret message")

      # Different room listener should NOT see it
      assert_no_output(listener_other_room, "Secret message")
    end

    test "handles empty message" do
      room = room_fixture()
      %{view: view} = connect_player(room: room, name: "Alice")

      send_command(view, "say")

      # Should get an error or usage message
      assert_eventual_output(view, "Say what?")
    end

    test "preserves message formatting" do
      room = room_fixture()

      [%{view: speaker}, %{view: listener}] =
        connect_players([
          [room: room, name: "Alice"],
          [room: room, name: "Bob"]
        ])

      send_command(speaker, "say Hey Bob, how's it going?")

      assert_eventual_output(listener, "Alice says: Hey Bob, how's it going?")
    end
  end
end
