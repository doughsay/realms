defmodule RealmsWeb.Commands.TellTest do
  use RealmsWeb.ConnCase, async: false

  import Realms.GameFixtures
  import RealmsWeb.GameTestHelpers

  describe "tell command" do
    test "sends private message to specific player" do
      room = room_fixture()

      [%{view: sender}, %{view: recipient}, %{view: bystander}] =
        connect_players([
          [room: room, name: "Alice"],
          [room: room, name: "Bob"],
          [room: room, name: "Carol"]
        ])

      send_command(sender, "tell bob Secret message")

      # Recipient should see the message
      assert_eventual_output(recipient, "Alice tells you: Secret message")

      # Bystander should NOT see it
      assert_no_output(bystander, "Secret message")
    end

    test "works across different rooms" do
      room1 = room_fixture()
      room2 = room_fixture()

      [%{view: sender}, %{view: recipient}] =
        connect_players([
          [room: room1, name: "Alice"],
          [room: room2, name: "Bob"]
        ])

      send_command(sender, "tell bob Message across rooms")

      assert_eventual_output(recipient, "Alice tells you: Message across rooms")
    end

    test "handles player name case insensitively" do
      room = room_fixture()

      [%{view: sender}, %{view: recipient}] =
        connect_players([
          [room: room, name: "Alice"],
          [room: room, name: "BobTheBuilder"]
        ])

      send_command(sender, "tell bobthebuilder Hey!")

      assert_eventual_output(recipient, "Alice tells you: Hey!")
    end

    test "shows error when player not found" do
      room = room_fixture()
      %{view: view} = connect_player(room: room, name: "Alice")

      send_command(view, "tell nobody Hello")

      assert_eventual_output(view, "Cannot find \"nobody\" online")
    end

    test "handles missing message" do
      room = room_fixture()
      %{view: view} = connect_player(room: room, name: "Alice")

      send_command(view, "tell bob")

      # Should get usage or error message
      assert_eventual_output(view, "tell")
    end
  end
end
