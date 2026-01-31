defmodule Realms.Repo.Migrations.CreatePlayers do
  use Ecto.Migration

  def change do
    create table(:players, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :text, null: false

      add :current_room_id, references(:rooms, type: :binary_id, on_delete: :restrict),
        null: false

      add :last_seen_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:players, [:current_room_id])
    create index(:players, [:name])
  end
end
