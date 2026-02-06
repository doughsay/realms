defmodule Realms.Repo.Migrations.AddItems do
  use Ecto.Migration

  def up do
    create table(:inventories, primary_key: false) do
      add :id, :binary_id, primary_key: true
      timestamps(type: :utc_datetime, updated_at: false)
    end

    create table(:items, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :text, null: false
      add :description, :text

      add :location_id, references(:inventories, type: :binary_id, on_delete: :restrict),
        null: false

      timestamps(type: :utc_datetime)
    end

    create table(:item_contents, primary_key: false) do
      add :item_id, references(:items, type: :binary_id, on_delete: :delete_all),
        null: false,
        primary_key: true

      add :inventory_id, references(:inventories, type: :binary_id, on_delete: :delete_all),
        null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    alter table(:rooms) do
      add :inventory_id, references(:inventories, type: :binary_id, on_delete: :restrict)
    end

    alter table(:players) do
      add :inventory_id, references(:inventories, type: :binary_id, on_delete: :restrict)
    end

    flush()

    execute(fn ->
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      %{rows: rooms} = repo().query!("SELECT id FROM rooms")

      Enum.each(rooms, fn [room_id] ->
        inv_id = Ecto.UUID.bingenerate()
        repo().query!("INSERT INTO inventories (id, inserted_at) VALUES ($1, $2)", [inv_id, now])
        repo().query!("UPDATE rooms SET inventory_id = $1 WHERE id = $2", [inv_id, room_id])
      end)

      %{rows: players} = repo().query!("SELECT id FROM players")

      Enum.each(players, fn [player_id] ->
        inv_id = Ecto.UUID.bingenerate()
        repo().query!("INSERT INTO inventories (id, inserted_at) VALUES ($1, $2)", [inv_id, now])
        repo().query!("UPDATE players SET inventory_id = $1 WHERE id = $2", [inv_id, player_id])
      end)
    end)

    alter table(:rooms) do
      modify :inventory_id, :binary_id, null: false
    end

    alter table(:players) do
      modify :inventory_id, :binary_id, null: false
    end

    create unique_index(:item_contents, [:item_id])
    create unique_index(:item_contents, [:inventory_id])
    create unique_index(:rooms, [:inventory_id])
    create unique_index(:players, [:inventory_id])
    create index(:items, [:location_id])
  end

  def down do
    drop index(:players, [:inventory_id])
    drop index(:rooms, [:inventory_id])
    drop index(:item_contents, [:inventory_id])
    drop index(:item_contents, [:item_id])
    drop index(:items, [:location_id])

    alter table(:players) do
      remove :inventory_id
    end

    alter table(:rooms) do
      remove :inventory_id
    end

    drop table(:item_contents)
    drop table(:items)
    drop table(:inventories)
  end
end
