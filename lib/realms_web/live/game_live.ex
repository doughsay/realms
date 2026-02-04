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

  attr :type, :atom, values: [:pre_wrap, :pre], required: true
  attr :content, :any, required: true

  defp section(assigns) do
    ~H"""
    <div
      phx-no-format
      class={["font-mono" | section_classes(@type)]}
    ><.content_node
      :for={item <- List.wrap(@content)}
      node={item}
      context={%{color: nil, bold: false, italic: false}}
    /></div>
    """
  end

  # Recursively renders a content node with styling context.
  attr :node, :any, required: true
  attr :context, :map, required: true

  defp content_node(%{node: text} = assigns) when is_binary(text) do
    ~H"""
    <span class={content_classes(@context)}>{@node}</span>
    """
  end

  defp content_node(%{node: {:color, color, inner}} = assigns) do
    assigns =
      assigns
      |> assign(:inner, inner)
      |> assign(:context, %{assigns.context | color: color})

    ~H"""
    <.content_node
      :for={item <- List.wrap(@inner)}
      node={item}
      context={@context}
    />
    """
  end

  defp content_node(%{node: {:bold, inner}} = assigns) do
    assigns =
      assigns
      |> assign(:inner, inner)
      |> assign(:context, %{assigns.context | bold: true})

    ~H"""
    <.content_node
      :for={item <- List.wrap(@inner)}
      node={item}
      context={@context}
    />
    """
  end

  defp content_node(%{node: {:italic, inner}} = assigns) do
    assigns =
      assigns
      |> assign(:inner, inner)
      |> assign(:context, %{assigns.context | italic: true})

    ~H"""
    <.content_node
      :for={item <- List.wrap(@inner)}
      node={item}
      context={@context}
    />
    """
  end

  defp content_node(%{node: list} = assigns) when is_list(list) do
    assigns = assign(assigns, :items, list)

    ~H"""
    <.content_node
      :for={item <- @items}
      node={item}
      context={@context}
    />
    """
  end

  defp section_classes(:pre_wrap) do
    ["whitespace-pre-wrap", "max-w-3xl"]
  end

  defp section_classes(:pre) do
    ["whitespace-pre", "overflow-x-auto"]
  end

  defp content_classes(context) do
    for {:ok, class} <- [
          color_class(context.color),
          bold_class(context.bold),
          italic_class(context.italic)
        ],
        do: class
  end

  defp italic_class(false), do: :error
  defp italic_class(true), do: {:ok, "italic"}

  defp bold_class(false), do: :error
  defp bold_class(true), do: {:ok, "font-bold"}

  # default to white
  defp color_class(nil), do: {:ok, "text-mud-white"}
  # grayscale
  defp color_class(:black), do: {:ok, "text-mud-black"}
  defp color_class(:gray_dark), do: {:ok, "text-mud-gray-dark"}
  defp color_class(:gray), do: {:ok, "text-mud-gray"}
  defp color_class(:gray_light), do: {:ok, "text-mud-gray-light"}
  defp color_class(:white), do: {:ok, "text-mud-white"}
  # base colors
  defp color_class(:red), do: {:ok, "text-mud-red"}
  defp color_class(:green), do: {:ok, "text-mud-green"}
  defp color_class(:yellow), do: {:ok, "text-mud-yellow"}
  defp color_class(:blue), do: {:ok, "text-mud-blue"}
  defp color_class(:magenta), do: {:ok, "text-mud-magenta"}
  defp color_class(:cyan), do: {:ok, "text-mud-cyan"}
  defp color_class(:orange), do: {:ok, "text-mud-orange"}
  defp color_class(:purple), do: {:ok, "text-mud-purple"}
  # bright colors
  defp color_class(:bright_red), do: {:ok, "text-mud-bright-red"}
  defp color_class(:bright_green), do: {:ok, "text-mud-bright-green"}
  defp color_class(:bright_yellow), do: {:ok, "text-mud-bright-yellow"}
  defp color_class(:bright_blue), do: {:ok, "text-mud-bright-blue"}
  defp color_class(:bright_magenta), do: {:ok, "text-mud-bright-magenta"}
  defp color_class(:bright_cyan), do: {:ok, "text-mud-bright-cyan"}
  defp color_class(:bright_orange), do: {:ok, "text-mud-bright-orange"}
  defp color_class(:bright_purple), do: {:ok, "text-mud-bright-purple"}
  # extended colors
  defp color_class(:teal), do: {:ok, "text-mud-teal"}
  defp color_class(:pink), do: {:ok, "text-mud-pink"}
  defp color_class(:lime), do: {:ok, "text-mud-lime"}
  defp color_class(:amber), do: {:ok, "text-mud-amber"}
  defp color_class(:indigo), do: {:ok, "text-mud-indigo"}
  defp color_class(:violet), do: {:ok, "text-mud-violet"}
  defp color_class(:rose), do: {:ok, "text-mud-rose"}
  defp color_class(:emerald), do: {:ok, "text-mud-emerald"}
  defp color_class(:sky), do: {:ok, "text-mud-sky"}
  defp color_class(:slate), do: {:ok, "text-mud-slate"}
  defp color_class(:brown), do: {:ok, "text-mud-brown"}
end
