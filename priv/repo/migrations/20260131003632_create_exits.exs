defmodule Realms.Repo.Migrations.CreateExits do
  use Ecto.Migration

  def change do
    create table(:exits, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :from_room_id, references(:rooms, type: :binary_id, on_delete: :delete_all), null: false
      add :to_room_id, references(:rooms, type: :binary_id, on_delete: :delete_all), null: false
      add :direction, :text, null: false
      timestamps(type: :utc_datetime)
    end

    create index(:exits, [:from_room_id])
    create index(:exits, [:to_room_id])

    create unique_index(:exits, [:from_room_id, :direction],
             name: :exits_from_to_direction_unique
           )
  end
end
