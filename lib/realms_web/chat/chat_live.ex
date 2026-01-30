defmodule RealmsWeb.ChatLive do
  use RealmsWeb, :live_view

  @topic "chat:lobby"

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Realms.PubSub, @topic)
    end

    {:ok,
     socket
     |> stream(:messages, [], limit: 100)
     |> assign(:form, to_form(%{"name" => "", "text" => ""}, as: :message))}
  end

  def handle_event("validate", %{"message" => message_params}, socket) do
    {:noreply, assign(socket, :form, to_form(message_params, as: :message))}
  end

  def handle_event(
        "send_message",
        %{"message" => %{"name" => name, "text" => message_text}},
        socket
      ) do
    if String.trim(name) != "" and String.trim(message_text) != "" do
      message = %{
        id: System.unique_integer([:positive]),
        name: name,
        text: message_text,
        timestamp: DateTime.utc_now()
      }

      Phoenix.PubSub.broadcast(Realms.PubSub, @topic, {:new_message, message})
    end

    {:noreply, assign(socket, :form, to_form(%{"name" => name, "text" => ""}, as: :message))}
  end

  def handle_info({:new_message, message}, socket) do
    {:noreply, stream_insert(socket, :messages, message)}
  end
end
