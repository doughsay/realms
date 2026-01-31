defmodule RealmsWeb.ChatLive do
  use RealmsWeb, :live_view

  alias Realms.PlayerHistoryStore
  alias Realms.Game

  def mount(_params, _session, socket) do
    player_id = socket.assigns.player_id

    # Load player from database
    {:ok, player} = Game.get_or_create_player(player_id)

    # Load history from DETS
    history = PlayerHistoryStore.get_history(player_id)

    socket =
      socket
      |> assign(:player_id, player_id)
      |> assign(:player, player)
      |> assign(:current_room, player.current_room)
      |> stream(:messages, history, limit: 100)
      |> assign(:form, to_form(%{"command" => ""}, as: :command))

    # Subscribe to current room topic
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Realms.PubSub, room_topic(player.current_room.id))
    end

    # If history is empty, show room description as first message
    socket =
      if history == [] do
        show_room_description(socket)
      else
        socket
      end

    {:ok, socket}
  end

  def handle_event("validate", %{"command" => command_params}, socket) do
    {:noreply, assign(socket, :form, to_form(command_params, as: :command))}
  end

  def handle_event("execute_command", %{"command" => %{"command" => command}}, socket) do
    command = String.trim(command)

    socket =
      command
      |> parse_command()
      |> execute_command(socket)

    # Clear the command input
    {:noreply, assign(socket, :form, to_form(%{"command" => ""}, as: :command))}
  end

  # Command Parser

  defp parse_command(""), do: :empty
  defp parse_command("look"), do: :look
  defp parse_command("exits"), do: :exits
  defp parse_command("help"), do: :help
  defp parse_command("say" <> message), do: {:say, String.trim(message)}

  defp parse_command(command) do
    direction =
      command
      |> String.downcase()

    if direction in ~w(north south east west northeast northwest southeast southwest up down in out) do
      {:move, direction}
    else
      {:unknown, command}
    end
  end

  # Command Executor

  defp execute_command(:empty, socket), do: socket

  defp execute_command(:look, socket) do
    show_room_description(socket)
  end

  defp execute_command(:exits, socket) do
    append_message(socket, :info, format_exits(socket.assigns.current_room))
  end

  defp execute_command(:help, socket) do
    help_text = """
    Available commands:
    - Movement: north, south, east, west, northeast, northwest, southeast, southwest, up, down, in, out
    - say <message>: Chat with players in the same room
    - look: Show current room description
    - exits: List available exits
    - help: Show this message
    """

    append_message(socket, :info, help_text)
  end

  defp execute_command({:say, message}, socket) do
    if String.trim(message) == "" do
      append_message(socket, :error, "Say what?")
    else
      # Broadcast to room - will receive back via PubSub
      broadcast_say(
        socket.assigns.current_room.id,
        socket.assigns.player.name,
        message
      )

      socket
    end
  end

  defp execute_command({:move, direction}, socket) do
    old_room = socket.assigns.current_room
    player = socket.assigns.player

    case Game.move_player(player, direction) do
      {:ok, new_room} ->
        # 1. Broadcast departure to old room (won't receive it ourselves)
        broadcast_departure(old_room.id, player.name, direction)

        # 2. Switch room subscriptions
        if connected?(socket) do
          Phoenix.PubSub.unsubscribe(Realms.PubSub, room_topic(old_room.id))
          Phoenix.PubSub.subscribe(Realms.PubSub, room_topic(new_room.id))
        end

        # 3. Broadcast arrival to new room (won't receive it ourselves)
        reverse_dir = reverse_direction(direction)
        broadcast_arrival(new_room.id, player.name, reverse_dir)

        # 4. Update state and show new room
        {:ok, updated_player} = Game.get_or_create_player(player.id)

        socket
        |> assign(:player, updated_player)
        |> assign(:current_room, new_room)
        |> show_room_description()

      {:error, :no_exit} ->
        append_message(socket, :error, "You can't go that way.")
    end
  end

  defp execute_command({:unknown, command}, socket) do
    append_message(socket, :error, "I don't understand '#{command}'. Type 'help' for commands.")
  end

  # PubSub Message Handlers

  def handle_info({:say_message, player_name, message}, socket) do
    content = "#{player_name} says: #{message}"
    {:noreply, append_message(socket, :say, content)}
  end

  def handle_info({:player_arrived, player_name, from_direction}, socket) do
    content = "#{player_name} arrives from the #{from_direction}."
    {:noreply, append_message(socket, :room_event, content)}
  end

  def handle_info({:player_departed, player_name, to_direction}, socket) do
    content = "#{player_name} leaves to the #{to_direction}."
    {:noreply, append_message(socket, :room_event, content)}
  end

  # Helper Functions

  defp show_room_description(socket) do
    room = socket.assigns.current_room

    # Format room output
    content = """
    #{room.name}
    #{room.description}

    #{format_exits(room)}
    """

    append_message(socket, :room, content)
  end

  defp format_exits(room) do
    exits = Game.list_exits_from_room(room.id)

    if exits == [] do
      "Obvious exits: none"
    else
      exit_list =
        exits
        |> Enum.map(& &1.direction)
        |> Enum.sort()
        |> Enum.join(", ")

      "Obvious exits: #{exit_list}"
    end
  end

  defp append_message(socket, type, content) do
    message = %{
      id: System.unique_integer([:positive]),
      type: type,
      content: content,
      timestamp: DateTime.utc_now()
    }

    # Store in history
    PlayerHistoryStore.append_message(socket.assigns.player_id, message)

    # Stream to UI
    stream_insert(socket, :messages, message)
  end

  # Message styling helper for template
  defp message_class(:room), do: "text-primary"
  defp message_class(:say), do: "text-base-content"
  defp message_class(:room_event), do: "text-info"
  defp message_class(:error), do: "text-error"
  defp message_class(:info), do: "text-info"
  defp message_class(_), do: "text-base-content"

  # PubSub Helpers

  defp room_topic(room_id), do: "room:#{room_id}"

  defp broadcast_say(room_id, player_name, message) do
    Phoenix.PubSub.broadcast(
      Realms.PubSub,
      room_topic(room_id),
      {:say_message, player_name, message}
    )
  end

  defp broadcast_departure(room_id, player_name, direction) do
    Phoenix.PubSub.broadcast_from(
      Realms.PubSub,
      self(),
      room_topic(room_id),
      {:player_departed, player_name, direction}
    )
  end

  defp broadcast_arrival(room_id, player_name, from_direction) do
    Phoenix.PubSub.broadcast_from(
      Realms.PubSub,
      self(),
      room_topic(room_id),
      {:player_arrived, player_name, from_direction}
    )
  end

  # Direction reversal for arrival messages
  defp reverse_direction("north"), do: "south"
  defp reverse_direction("south"), do: "north"
  defp reverse_direction("east"), do: "west"
  defp reverse_direction("west"), do: "east"
  defp reverse_direction("northeast"), do: "southwest"
  defp reverse_direction("northwest"), do: "southeast"
  defp reverse_direction("southeast"), do: "northwest"
  defp reverse_direction("southwest"), do: "northeast"
  defp reverse_direction("up"), do: "down"
  defp reverse_direction("down"), do: "up"
  defp reverse_direction("in"), do: "out"
  defp reverse_direction("out"), do: "in"
end
