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
    - look: Show current room description
    - exits: List available exits
    - help: Show this message
    """

    append_message(socket, :info, help_text)
  end

  defp execute_command({:move, direction}, socket) do
    player = socket.assigns.player

    case Game.move_player(player, direction) do
      {:ok, new_room} ->
        # Reload player to get updated current_room_id
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
  defp message_class(:movement), do: "text-success"
  defp message_class(:error), do: "text-error"
  defp message_class(:info), do: "text-info"
  defp message_class(_), do: "text-base-content"
end
