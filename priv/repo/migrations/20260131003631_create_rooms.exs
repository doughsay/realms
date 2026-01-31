defmodule Realms.Repo.Migrations.CreateRooms do
  use Ecto.Migration

  def change do
    create table(:rooms, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :text, null: false
      add :description, :text, null: false
      timestamps(type: :utc_datetime)
    end

    create index(:rooms, [:name])
  end
end
