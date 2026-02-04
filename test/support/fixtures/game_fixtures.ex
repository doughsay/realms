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
    case Game.get_room_by_name("Town Square") do
      nil ->
        {:ok, room} =
          Game.create_room(%{
            name: "Town Square",
            description: "A bustling town square."
          })

        room

      room ->
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
end
