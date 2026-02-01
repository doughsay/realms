defmodule Realms.Repo.Migrations.AddDespawnReasonToPlayers do
  use Ecto.Migration

  def change do
    alter table(:players) do
      add :despawn_reason, :text
    end
  end
end
