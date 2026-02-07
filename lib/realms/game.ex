defmodule Realms.Game do
  @moduledoc """
  The Game context for managing game state.
  """

  import Ecto.Query

  alias Realms.Game.{Room, Exit, Player, Item, Inventory, ItemContent}
  alias Realms.Repo

  require Logger

  # Item functions

  @doc """
  Creates an item.

  Options:
    * `:has_inventory` - boolean, if true creates an inventory for the item (e.g. for a bag).
  """
  def create_item(attrs, opts \\ []) do
    tx(fn ->
      with {:ok, item} <- %Item{} |> Item.changeset(attrs) |> Repo.insert(),
           {:ok, _inventory_or_nil} <-
             maybe_create_item_inventory(item, Keyword.get(opts, :has_inventory, false)) do
        {:ok, item}
      end
    end)
  end

  defp maybe_create_item_inventory(%Item{} = item, true) do
    with {:ok, inventory} <- Repo.insert(%Inventory{}),
         {:ok, _item_content} <-
           %ItemContent{}
           |> ItemContent.changeset(%{item_id: item.id, inventory_id: inventory.id})
           |> Repo.insert() do
      {:ok, inventory}
    end
  end

  defp maybe_create_item_inventory(_item, false), do: {:ok, nil}

  @doc """
  Moves an item to a specific inventory.

  If the item is already somewhere else, it is moved.
  """
  def move_item_to_inventory(%Item{} = item, inventory_id) do
    item
    |> Item.changeset(%{location_id: inventory_id})
    |> Repo.update()
  end

  @doc """
  Moves an item to a room's inventory.
  """
  def move_item_to_room(%Item{} = item, %Room{} = room) do
    move_item_to_inventory(item, room.inventory_id)
  end

  @doc """
  Moves an item to a player's inventory.
  """
  def move_item_to_player(%Item{} = item, %Player{} = player) do
    move_item_to_inventory(item, player.inventory_id)
  end

  @doc """
  Moves an item inside another item (e.g., putting a sword in a bag).

  Returns `{:ok, item_location}` or `{:error, :no_inventory}` if the container cannot hold items.
  """
  def move_item_to_item(%Item{} = item, %Item{} = container) do
    case Repo.get_by(ItemContent, item_id: container.id) do
      %ItemContent{inventory_id: inventory_id} ->
        move_item_to_inventory(item, inventory_id)

      nil ->
        {:error, :no_inventory}
    end
  end

  @doc """
  Lists items in a specific inventory.
  """
  def list_items_in_inventory(inventory_id) do
    Item
    |> where([i], i.location_id == ^inventory_id)
    |> Repo.all()
  end

  @doc """
  Finds a single item in an inventory by matching the search term against
  word prefixes in the item's name. Case-insensitive.

  Returns {:ok, item} if exactly one match found,
  {:error, :no_matching_item} if no matches,
  {:error, :ambiguous} if multiple matches.

  ## Examples

      find_item_in_inventory(inventory_id, "sw")
      # Matches "rusty iron sword" (matches "sword")
      # Matches "swift dagger" (matches "swift")
      # Returns {:error, :ambiguous} if both exist
  """
  def find_item_in_inventory(inventory_id, search_term) do
    find_item_in_inventories([inventory_id], search_term)
  end

  @doc """
  Finds a single item across multiple inventories by matching the search term
  against word prefixes in the item's name. Case-insensitive.

  Returns {:ok, item} if exactly one match found across all inventories,
  {:error, :no_matching_item} if no matches,
  {:error, :ambiguous} if multiple matches.

  ## Examples

      find_item_in_inventories([player_inv_id, room_inv_id], "sw")
      # Searches both player inventory and room inventory
      # Returns the item if exactly one match across both
  """
  def find_item_in_inventories(inventory_ids, search_term) when is_list(inventory_ids) do
    search_term = String.downcase(search_term)

    # Pattern matches: starts with term OR has space before term
    # "sw" matches "sword" and "swift dagger"
    start_pattern = "#{search_term}%"
    word_pattern = "% #{search_term}%"

    Item
    |> where([i], i.location_id in ^inventory_ids)
    |> where(
      [i],
      ilike(i.name, ^start_pattern) or ilike(i.name, ^word_pattern)
    )
    |> Repo.all()
    |> case do
      [] -> {:error, :no_matching_item}
      [item] -> {:ok, item}
      _multiple -> {:error, :ambiguous}
    end
  end

  @doc """
  Lists items currently in a room.
  """
  def list_items_in_room(%Room{} = room) do
    list_items_in_inventory(room.inventory_id)
  end

  @doc """
  Lists items currently carried by a player.
  """
  def list_items_in_player(%Player{} = player) do
    list_items_in_inventory(player.inventory_id)
  end

  @doc """
  Lists items contained inside another item.

  Returns {:ok, items} if the item is a container,
  {:error, :not_a_container} if the item cannot hold items.
  """
  def list_items_in_item(%Item{} = container) do
    case Repo.get_by(ItemContent, item_id: container.id) do
      nil -> {:error, :not_a_container}
      %ItemContent{inventory_id: inventory_id} -> {:ok, list_items_in_inventory(inventory_id)}
    end
  end

  @doc """
  Gets the inventory ID associated with a container item.
  Returns nil if the item is not a container.
  """
  def get_container_inventory_id(%Item{} = container) do
    case Repo.get_by(ItemContent, item_id: container.id) do
      nil -> nil
      %ItemContent{inventory_id: inventory_id} -> inventory_id
    end
  end

  @doc """
  Fetches the inventory ID associated with a container item.
  Returns {:ok, inventory_id} if the item is a container, {:error, :not_a_container} otherwise.
  """
  def fetch_container_inventory_id(%Item{} = container) do
    case Repo.get_by(ItemContent, item_id: container.id) do
      nil -> {:error, :not_a_container}
      %ItemContent{inventory_id: inventory_id} -> {:ok, inventory_id}
    end
  end

  # Room functions

  @doc """
  Gets a single room by ID. Raises if not found.
  """
  def get_room!(id) do
    Repo.get!(Room, id)
  end

  @doc """
  Gets a room by name. Returns {:ok, room} or {:error, :room_not_found}.
  """
  def fetch_room_by_name(name) do
    Repo.fetch_by(Room, [name: name], error_tag: :room_not_found)
  end

  @doc """
  Creates a room.
  """
  def create_room(attrs) do
    tx(fn ->
      with {:ok, inventory} <- Repo.insert(%Inventory{}) do
        attrs = Map.put(attrs, :inventory_id, inventory.id)

        %Room{}
        |> Room.changeset(attrs)
        |> Repo.insert()
      end
    end)
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
    tx(fn ->
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
        {:ok, {exit1, exit2}}
      end
    end)
  end

  # Player functions

  @doc """
  Gets a player by ID.
  Returns nil if not found.
  """
  def get_player(id) do
    Repo.get(Player, id)
  end

  @doc """
  Gets a player by ID. Raises if not found.
  """
  def get_player!(id) do
    Repo.get!(Player, id)
  end

  @doc """
  Creates a player.
  """
  def create_player(attrs) do
    tx(fn ->
      with {:ok, inventory} <- Repo.insert(%Inventory{}) do
        attrs = Map.put(attrs, :inventory_id, inventory.id)

        %Player{}
        |> Player.changeset(attrs)
        |> Repo.insert()
      end
    end)
  end

  @doc """
  Updates a player and returns it with all associations preloaded.
  """
  def update_player(%Player{} = player, attrs) do
    player
    |> Player.changeset(attrs)
    |> Repo.update()
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
    tx(fn ->
      with {:ok, town_square} <- fetch_room_by_name("Town Square"),
           {:ok, inventory} <- Repo.insert(%Inventory{}),
           attrs =
             attrs
             |> Map.put(:user_id, user_id)
             |> Map.put(:spawn_room_id, town_square.id)
             |> Map.put(:last_seen_at, DateTime.utc_now())
             |> Map.put(:inventory_id, inventory.id),
           {:ok, player} <-
             %Player{}
             |> Player.changeset(attrs)
             |> Repo.insert(),
           duck_name = "#{Map.get(attrs, :name) || "Player"}'s Lucky Rubber Duck",
           {:ok, _duck} <-
             create_item(%{
               name: duck_name,
               description:
                 "A small, yellow rubber duck. It squeaks when you squeeze it. It seems to bring you comfort.",
               location_id: inventory.id
             }) do
        {:ok, player}
      else
        {:error, :room_not_found} ->
          {:error, :no_starting_room}

        {:error, reason} ->
          {:error, reason}
      end
    end)
  end

  @doc """
  Moves a player in a direction. Updates their current_room_id.
  Returns {:ok, new_room} or {:error, reason}.
  """
  def move_player(%Player{} = player, direction) do
    tx(fn ->
      case get_exit_by_direction(player.current_room_id, direction) do
        nil ->
          {:error, :no_exit}

        %Exit{to_room: new_room} ->
          {:ok, _player} = update_player(player, %{current_room_id: new_room.id})
          {:ok, new_room}
      end
    end)
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
  Finds online players by matching the search term against word prefixes
  in their name. Case-insensitive.

  Returns a list of matching players (0, 1, or more).

  ## Examples

      online_players_by_name_prefix("bar")
      # Matches "Barfos", "Sir Bartholomew", etc.
  """
  def online_players_by_name_prefix(text) do
    search_term = String.downcase(text)

    # Pattern matches: starts with term OR has space before term
    start_pattern = "#{search_term}%"
    word_pattern = "% #{search_term}%"

    Player
    |> where([u], u.connection_status == :online)
    |> where(
      [u],
      ilike(u.name, ^start_pattern) or ilike(u.name, ^word_pattern)
    )
    |> Repo.all()
  end

  @doc """
  Sets a player's connection status.
  Returns {:ok, player} or {:error, changeset}.
  """
  def set_player_status(player_id, status) when status in [:online, :away, :offline] do
    player = get_player!(player_id)
    update_player(player, %{connection_status: status})
  end

  @doc """
  Spawns a player in a room.
  Sets current_room_id, connection_status to :online, and clears despawn_reason.
  Accepts either a player_id or a Player struct.
  Returns {:ok, player} or {:error, changeset}.
  """
  def spawn_player(player_id, room_id) when is_binary(player_id) do
    player = get_player!(player_id)
    spawn_player(player, room_id)
  end

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
  Accepts either a player_id or a Player struct.
  Returns {:ok, player} or {:error, changeset}.
  """
  def despawn_player(player_or_id, reason, opts \\ [])

  def despawn_player(player_id, reason, opts) when is_binary(player_id) do
    player = get_player!(player_id)
    despawn_player(player, reason, opts)
  end

  def despawn_player(%Player{} = player, reason, opts) do
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

  # Serializable and retryable transactions

  @type tx_result :: {:ok, term()} | {:error, term()}

  @doc """
  Executes a function inside a transaction with isolation level set to
  "serializable" and automatically retries on serialization failures.

  Retries up to `retries` times (default 10) if a serialization failure occurs.
  Retries use exponential backoff with jitter to reduce contention.

  Ignores nested calls if already inside a transaction.
  """
  @spec tx((-> tx_result()), non_neg_integer()) :: tx_result()
  def tx(fun, retries \\ 10) do
    if Repo.in_transaction?() do
      fun.()
    else
      do_tx(fun, retries, 0)
    end
  end

  defp do_tx(fun, max_retries, attempt) do
    Repo.transact(fn ->
      Repo.query!("SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;")
      fun.()
    end)
  rescue
    e in Postgrex.Error ->
      if e.postgres.code == :serialization_failure and attempt < max_retries do
        base_delay = :math.pow(2, attempt) |> round()
        jitter = :rand.uniform(base_delay)
        delay_ms = base_delay + jitter

        Logger.warning(
          "Transaction failed with serialization failure. Retrying... (attempt #{attempt + 1}/#{max_retries}) Delay: #{delay_ms}ms"
        )

        Process.sleep(delay_ms)

        do_tx(fun, max_retries, attempt + 1)
      else
        reraise e, __STACKTRACE__
      end
  end
end
