defmodule Realms.Repo.Migrations.AddMobs do
  use Ecto.Migration

  def change do
    create table(:mobs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :text, null: false
      add :long_name, :text, null: false
      add :description, :text, null: false
      add :behavior, :text, null: false

      add :current_room_id, references(:rooms, type: :binary_id, on_delete: :restrict),
        null: false

      add :inventory_id, references(:inventories, type: :binary_id, on_delete: :restrict)

      timestamps(type: :utc_datetime)
    end

    create index(:mobs, [:current_room_id])
    create index(:mobs, [:name])
    create unique_index(:mobs, [:inventory_id])
  end
end
