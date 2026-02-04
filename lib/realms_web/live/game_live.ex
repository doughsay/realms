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

  # Helper Functions & Rendering Components

  # Renders a section with appropriate whitespace handling.
  attr :section, :any, required: true

  defp render_section(assigns) do
    {section_type, content} = assigns.section

    case section_type do
      :pre_wrap ->
        assigns = assign(assigns, :content, content)

        ~H"""
        <div phx-no-format class="whitespace-pre-wrap font-mono">
          <%= render_content_nodes(@content) %>
        </div>
        """

      :pre ->
        assigns = assign(assigns, :content, content)

        ~H"""
        <div phx-no-format class="whitespace-pre font-mono overflow-x-auto">
          <%= render_content_nodes(@content) %>
        </div>
        """
    end
  end

  # Entry point for rendering content nodes.
  defp render_content_nodes(content) do
    render_content_with_context(content, %{color: nil, bold: false, italic: false})
  end

  # Recursively renders content nodes with accumulated styling context.
  defp render_content_with_context(text, context) when is_binary(text) do
    classes = content_classes(context)
    escaped = text |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
    Phoenix.HTML.raw("<span class=\"#{classes}\">#{escaped}</span>")
  end

  defp render_content_with_context({:color, color, inner}, context) do
    render_content_with_context(inner, %{context | color: color})
  end

  defp render_content_with_context({:bold, inner}, context) do
    render_content_with_context(inner, %{context | bold: true})
  end

  defp render_content_with_context({:italic, inner}, context) do
    render_content_with_context(inner, %{context | italic: true})
  end

  defp render_content_with_context(list, context) when is_list(list) do
    list
    |> Enum.map(&render_content_with_context(&1, context))
    |> Phoenix.HTML.raw()
  end

  # Builds CSS class string from styling context.
  defp content_classes(context) do
    [
      if(context.color, do: color_class(context.color), else: "text-mud-white"),
      if(context.bold, do: "font-bold"),
      if(context.italic, do: "italic")
    ]
    |> Enum.filter(& &1)
    |> Enum.join(" ")
  end

  # Maps color atom to CSS class name.
  defp color_class(color) do
    "text-mud-#{color |> Atom.to_string() |> String.replace("_", "-")}"
  end
end
