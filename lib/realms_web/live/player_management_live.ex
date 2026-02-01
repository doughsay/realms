defmodule RealmsWeb.PlayerManagementLive do
  use RealmsWeb, :live_view

  alias Realms.Game

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    players = Game.list_players_for_user(user.id)

    socket =
      socket
      |> assign(:players, players)
      |> assign(:form, to_form(%{"name" => ""}, as: :player))
      |> assign(:editing, nil)

    {:ok, socket}
  end

  def handle_event("validate", %{"player" => player_params}, socket) do
    {:noreply, assign(socket, :form, to_form(player_params, as: :player))}
  end

  def handle_event("create", %{"player" => %{"name" => name}}, socket) do
    user = socket.assigns.current_scope.user

    case Game.create_player_for_user(user.id, %{name: name}) do
      {:ok, _player} ->
        players = Game.list_players_for_user(user.id)

        socket =
          socket
          |> assign(:players, players)
          |> assign(:form, to_form(%{"name" => ""}, as: :player))
          |> put_flash(:info, "Player created successfully")

        {:noreply, socket}

      {:error, :no_starting_room} ->
        socket =
          socket
          |> put_flash(:error, "Cannot create player: no starting room available")

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: :player))}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    player = Game.get_player!(id)
    {:ok, _} = Game.delete_player(player)

    players = Game.list_players_for_user(socket.assigns.current_scope.user.id)

    socket =
      socket
      |> assign(:players, players)
      |> put_flash(:info, "Player deleted successfully")

    {:noreply, socket}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    player = Game.get_player!(id)
    {:noreply, assign(socket, :editing, player)}
  end

  def handle_event("cancel_edit", _params, socket) do
    {:noreply, assign(socket, :editing, nil)}
  end

  def handle_event("update", %{"id" => id, "name" => name}, socket) do
    player = Game.get_player!(id)

    case Game.update_player(player, %{name: name}) do
      {:ok, _player} ->
        players = Game.list_players_for_user(socket.assigns.current_scope.user.id)

        socket =
          socket
          |> assign(:players, players)
          |> assign(:editing, nil)
          |> put_flash(:info, "Player updated successfully")

        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update player")}
    end
  end
end
