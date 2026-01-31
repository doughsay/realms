defmodule Realms.Game do
  @moduledoc """
  The Game context for managing rooms and exits.
  """

  import Ecto.Query
  alias Realms.Repo
  alias Realms.Game.{Room, Exit}

  # Room functions

  @doc """
  Returns the list of all rooms.
  """
  def list_rooms do
    Repo.all(Room)
  end

  @doc """
  Gets a single room by ID. Raises if not found.
  """
  def get_room!(id) do
    Repo.get!(Room, id)
  end

  @doc """
  Gets a room by name. Returns nil if not found.
  """
  def get_room_by_name(name) do
    Repo.get_by(Room, name: name)
  end

  @doc """
  Gets a room with its exits preloaded.
  """
  def get_room_with_exits!(id) do
    Room
    |> Repo.get!(id)
    |> Repo.preload(:exits_from)
  end

  @doc """
  Creates a room.
  """
  def create_room(attrs) do
    %Room{}
    |> Room.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a room.
  """
  def update_room(%Room{} = room, attrs) do
    room
    |> Room.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a room.
  """
  def delete_room(%Room{} = room) do
    Repo.delete(room)
  end

  # Exit functions

  @doc """
  Lists all exits from a specific room.
  """
  def list_exits_from_room(room_id) do
    Exit
    |> where([e], e.from_room_id == ^room_id)
    |> preload(:to_room)
    |> Repo.all()
  end

  @doc """
  Gets an exit by direction from a specific room.
  """
  def get_exit_by_direction(from_room_id, direction) do
    Exit
    |> where([e], e.from_room_id == ^from_room_id and e.direction == ^direction)
    |> preload(:to_room)
    |> Repo.one()
  end

  @doc """
  Creates a one-way exit.
  """
  def create_exit(attrs) do
    %Exit{}
    |> Exit.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates bidirectional exits between two rooms.
  """
  def create_bidirectional_exit(from_room_id, to_room_id, direction, reverse_direction) do
    Repo.transaction(fn ->
      with {:ok, exit1} <-
             create_exit(%{
               from_room_id: from_room_id,
               to_room_id: to_room_id,
               direction: direction
             }),
           {:ok, exit2} <-
             create_exit(%{
               from_room_id: to_room_id,
               to_room_id: from_room_id,
               direction: reverse_direction
             }) do
        {exit1, exit2}
      else
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  @doc """
  Deletes an exit.
  """
  def delete_exit(%Exit{} = exit) do
    Repo.delete(exit)
  end

  # Navigation helpers

  @doc """
  Attempts to move from a room in a given direction.
  Returns {:ok, room} if successful, {:error, :no_exit} otherwise.
  """
  def move(from_room_id, direction) do
    case get_exit_by_direction(from_room_id, direction) do
      %Exit{to_room: to_room} -> {:ok, to_room}
      nil -> {:error, :no_exit}
    end
  end

  @doc """
  Gets a map of available exits from a room.
  Returns a map of direction => destination room name.
  """
  def get_available_exits(room_id) do
    room_id
    |> list_exits_from_room()
    |> Enum.map(fn exit -> {exit.direction, exit.to_room.name} end)
    |> Map.new()
  end
end
