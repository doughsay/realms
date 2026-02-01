defmodule RealmsWeb.GameLive do
  use RealmsWeb, :live_view

  alias Realms.PlayerServer
  alias RealmsWeb.Message

  def mount(_params, %{"player_id" => player_id}, socket) do
    case PlayerServer.ensure_started(player_id) do
      {:ok, _pid} ->
        if connected?(socket) do
          PlayerServer.register_view(player_id, self())
        end

        state = PlayerServer.get_state(player_id)
        history = PlayerServer.get_history(player_id)

        socket =
          socket
          |> assign(:player_id, player_id)
          |> assign(:player, state.player)
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

  def terminate(_reason, socket) do
    if player_id = socket.assigns[:player_id] do
      PlayerServer.unregister_view(player_id, self())
    end

    :ok
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

  defp message_class(:room), do: "text-primary"
  defp message_class(:say), do: "text-base-content"
  defp message_class(:room_event), do: "text-info"
  defp message_class(:players), do: "text-accent"
  defp message_class(:error), do: "text-error"
  defp message_class(:info), do: "text-info"
  defp message_class(:command_echo), do: "text-base-content/40"
  defp message_class(_), do: "text-base-content"
end
