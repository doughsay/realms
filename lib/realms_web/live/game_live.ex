defmodule RealmsWeb.GameLive do
  use RealmsWeb, :live_view

  alias Realms.Game
  alias Realms.Messaging.Message
  alias Realms.PlayerServer

  def mount(_params, %{"player_id" => player_id}, socket) do
    case PlayerServer.ensure_started(player_id) do
      {:ok, _pid} ->
        if connected?(socket) do
          PlayerServer.register_view(player_id, self())
        end

        player = Game.get_player!(player_id)
        history = PlayerServer.get_history(player_id)

        socket =
          socket
          |> assign(:player_id, player_id)
          |> assign(:player_name, player.name)
          |> stream(:messages, history, limit: 100)
          |> assign(:form, to_form(%{"command" => ""}, as: :command))

        {:ok, socket}

      {:error, _reason} ->
        {:ok, assign(socket, :player_id, nil)}
    end
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :player_id, nil)}
  end

  def handle_event("validate", %{"command" => command_params}, socket) do
    {:noreply, assign(socket, :form, to_form(command_params, as: :command))}
  end

  def handle_event("execute_command", %{"command" => %{"command" => input}}, socket) do
    input = String.trim(input)
    player_id = socket.assigns.player_id

    if input != "" do
      PlayerServer.handle_input(player_id, input)
    end

    {:noreply, assign(socket, :form, to_form(%{"command" => ""}, as: :command))}
  end

  # PubSub Message Handlers

  def handle_info({:game_message, %Message{} = message}, socket) do
    {:noreply, stream_insert(socket, :messages, message)}
  end

  # Helper Functions

  # Build CSS classes for a segment (color + modifiers)
  defp segment_classes(segment) do
    color_class = color_to_class(segment.color || :white)
    modifier_classes = Enum.map(segment.modifiers, &modifier_to_class/1)

    [color_class | modifier_classes]
    |> Enum.join(" ")
  end

  # Map color atoms to Tailwind classes
  defp color_to_class(:black), do: "text-mud-black"
  defp color_to_class(:gray_dark), do: "text-mud-gray-dark"
  defp color_to_class(:gray), do: "text-mud-gray"
  defp color_to_class(:gray_light), do: "text-mud-gray-light"
  defp color_to_class(:white), do: "text-mud-white"

  defp color_to_class(:red), do: "text-mud-red"
  defp color_to_class(:green), do: "text-mud-green"
  defp color_to_class(:yellow), do: "text-mud-yellow"
  defp color_to_class(:blue), do: "text-mud-blue"
  defp color_to_class(:magenta), do: "text-mud-magenta"
  defp color_to_class(:cyan), do: "text-mud-cyan"
  defp color_to_class(:orange), do: "text-mud-orange"
  defp color_to_class(:purple), do: "text-mud-purple"

  defp color_to_class(:bright_red), do: "text-mud-bright-red"
  defp color_to_class(:bright_green), do: "text-mud-bright-green"
  defp color_to_class(:bright_yellow), do: "text-mud-bright-yellow"
  defp color_to_class(:bright_blue), do: "text-mud-bright-blue"
  defp color_to_class(:bright_magenta), do: "text-mud-bright-magenta"
  defp color_to_class(:bright_cyan), do: "text-mud-bright-cyan"
  defp color_to_class(:bright_orange), do: "text-mud-bright-orange"
  defp color_to_class(:bright_purple), do: "text-mud-bright-purple"

  defp color_to_class(:teal), do: "text-mud-teal"
  defp color_to_class(:pink), do: "text-mud-pink"
  defp color_to_class(:lime), do: "text-mud-lime"
  defp color_to_class(:amber), do: "text-mud-amber"
  defp color_to_class(:indigo), do: "text-mud-indigo"
  defp color_to_class(:violet), do: "text-mud-violet"
  defp color_to_class(:rose), do: "text-mud-rose"
  defp color_to_class(:emerald), do: "text-mud-emerald"
  defp color_to_class(:sky), do: "text-mud-sky"
  defp color_to_class(:slate), do: "text-mud-slate"
  defp color_to_class(:brown), do: "text-mud-brown"

  defp color_to_class(_), do: "text-mud-white"

  defp modifier_to_class(:bold), do: "font-bold"
  defp modifier_to_class(:italic), do: "italic"
  defp modifier_to_class(_), do: ""
end
