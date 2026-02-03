defmodule Realms.Game do
  @moduledoc """
  The Game context for managing rooms and exits.
  """

  import Ecto.Query

  alias Realms.Game.{Room, Exit, Player}
  alias Realms.Repo

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
    |> Map.new(fn exit -> {exit.direction, exit.to_room.name} end)
  end

  # Player functions

  @doc """
  Gets a player by ID with all room associations and user preloaded.
  Returns nil if not found.
  """
  def get_player(id) do
    Player
    |> Repo.get(id)
    |> case do
      nil -> nil
      player -> Repo.preload(player, [:current_room, :spawn_room, :user])
    end
  end

  def get_player!(id) do
    Player
    |> Repo.get!(id)
    |> Repo.preload([:current_room, :spawn_room, :user])
  end

  @doc """
  Creates a player.
  """
  def create_player(attrs) do
    %Player{}
    |> Player.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a player and returns it with all associations preloaded.
  """
  def update_player(%Player{} = player, attrs) do
    with {:ok, updated_player} <-
           player
           |> Player.changeset(attrs)
           |> Repo.update() do
      {:ok, Repo.preload(updated_player, [:current_room, :spawn_room, :user], force: true)}
    end
  end

  @doc """
  Deletes a player.
  """
  def delete_player(%Player{} = player) do
    Repo.delete(player)
  end

  @doc """
  Lists all players for a user.
  """
  def list_players_for_user(user_id) do
    Player
    |> where([p], p.user_id == ^user_id)
    |> order_by([p], desc: p.inserted_at)
    |> Repo.all()
  end

  @doc """
  Creates a player for a user with the given attributes.
  The player will spawn in the Town Square.
  """
  def create_player_for_user(user_id, attrs) do
    town_square = get_room_by_name("Town Square")

    if is_nil(town_square) do
      {:error, :no_starting_room}
    else
      attrs =
        attrs
        |> Map.put(:user_id, user_id)
        |> Map.put(:spawn_room_id, town_square.id)
        |> Map.put(:last_seen_at, DateTime.utc_now())

      %Player{}
      |> Player.changeset(attrs)
      |> Repo.insert()
    end
  end

  @doc """
  Moves a player in a direction. Updates their current_room_id.
  Returns {:ok, new_room} or {:error, reason}.
  """
  def move_player(%Player{} = player, direction) do
    case get_exit_by_direction(player.current_room_id, direction) do
      nil ->
        {:error, :no_exit}

      %Exit{to_room: new_room} ->
        case update_player(player, %{current_room_id: new_room.id}) do
          {:ok, _updated_player} -> {:ok, new_room}
          error -> error
        end
    end
  end

  @doc """
  Lists all players currently in a specific room.
  """
  def players_in_room(room_id) do
    Player
    |> where([p], p.current_room_id == ^room_id)
    |> Repo.all()
  end

  @doc """
  Spawns a player in a room.
  Sets current_room_id, connection_status to :online, and clears despawn_reason.
  Returns {:ok, player} or {:error, changeset}.
  """
  def spawn_player(%Player{} = player, room_id) do
    update_player(player, %{
      current_room_id: room_id,
      connection_status: :online,
      despawn_reason: nil
    })
  end

  @doc """
  Despawns a player with the given reason.
  Clears current_room_id, sets connection_status to :offline, records despawn_reason.
  Updates spawn_room_id to preserve last location if current_room_id is set.
  Returns {:ok, player} or {:error, changeset}.
  """
  def despawn_player(%Player{} = player, reason, opts \\ []) do
    attrs = %{
      connection_status: :offline,
      despawn_reason: reason
    }

    attrs =
      if player.current_room_id && !Keyword.get(opts, :skip_spawn_room_update, false) do
        Map.put(attrs, :spawn_room_id, player.current_room_id)
      else
        attrs
      end

    attrs = Map.put(attrs, :current_room_id, nil)

    update_player(player, attrs)
  end

  @doc """
  Despawns all currently spawned players with the given reason.
  Uses a bulk update for performance.
  Returns {:ok, count} where count is the number of players despawned.
  """
  def despawn_all_players(reason) do
    query =
      from p in Player,
        where: not is_nil(p.current_room_id),
        update: [
          set: [
            spawn_room_id: coalesce(p.current_room_id, p.spawn_room_id),
            current_room_id: nil,
            connection_status: :offline,
            despawn_reason: ^reason,
            updated_at: ^DateTime.utc_now()
          ]
        ]

    {count, _} = Repo.update_all(query, [])

    {:ok, count}
  end
end
