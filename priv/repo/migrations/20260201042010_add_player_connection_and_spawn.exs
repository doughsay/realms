defmodule Realms.Repo.Migrations.AddPlayerConnectionAndSpawn do
  use Ecto.Migration

  def change do
    alter table(:players) do
      add :connection_status, :text, default: "offline", null: false
      add :spawn_room_id, references(:rooms, on_delete: :nilify_all, type: :binary_id)
      modify :current_room_id, :binary_id, null: true
    end

    create index(:players, [:spawn_room_id])
  end
end