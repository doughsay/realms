defmodule Realms.GameFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Realms.Game` context.
  """

  alias Realms.Game

  @doc """
  Generate a unique player name.
  """
  def unique_player_name do
    "Player#{System.unique_integer([:positive])}"
  end

  @doc """
  Get or create the Town Square room.
  """
  def town_square_fixture do
    case Game.fetch_room_by_name("Town Square") do
      {:error, :room_not_found} ->
        {:ok, room} =
          Game.create_room(%{
            name: "Town Square",
            description: "A bustling town square."
          })

        room

      {:ok, room} ->
        room
    end
  end

  @doc """
  Generate a player for a given user.
  Requires a Town Square room to exist.
  """
  def player_fixture(user, attrs \\ %{}) do
    town_square = town_square_fixture()

    attrs =
      attrs
      |> Enum.into(%{
        name: unique_player_name(),
        user_id: user.id,
        current_room_id: town_square.id,
        last_seen_at: DateTime.utc_now()
      })

    {:ok, player} = Game.create_player(attrs)
    player
  end

  @doc """
  Generate a unique item name.
  """
  def unique_item_name do
    "item#{System.unique_integer([:positive])}"
  end

  @doc """
  Generate an item.
  """
  def item_fixture(attrs \\ %{}) do
    attrs =
      attrs
      |> Enum.into(%{
        name: unique_item_name(),
        description: "A simple item."
      })

    {:ok, item} = Game.create_item(attrs)
    item
  end

  @doc """
  Generate a room.
  """
  def room_fixture(attrs \\ %{}) do
    attrs =
      attrs
      |> Enum.into(%{
        name: "Room #{System.unique_integer([:positive])}",
        description: "A generic room."
      })

    {:ok, room} = Game.create_room(attrs)
    room
  end

  @doc """
  Create an exit between two rooms.
  """
  def exit_fixture(from_room, to_room, direction) do
    {:ok, exit} =
      Game.create_exit(%{
        from_room_id: from_room.id,
        to_room_id: to_room.id,
        direction: direction
      })

    exit
  end
end
