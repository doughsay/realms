defmodule Realms.Game.Player do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "players" do
    field :name, :string
    field :last_seen_at, :utc_datetime
    field :connection_status, Ecto.Enum, values: [:online, :offline, :away], default: :offline
    field :despawn_reason, :string

    belongs_to :current_room, Realms.Game.Room,
      foreign_key: :current_room_id,
      type: :binary_id

    belongs_to :spawn_room, Realms.Game.Room,
      foreign_key: :spawn_room_id,
      type: :binary_id

    belongs_to :user, Realms.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(player, attrs) do
    player
    |> cast(attrs, [
      :id,
      :name,
      :current_room_id,
      :spawn_room_id,
      :connection_status,
      :last_seen_at,
      :user_id,
      :despawn_reason
    ])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 100)
    |> foreign_key_constraint(:current_room_id)
    |> foreign_key_constraint(:spawn_room_id)
    |> foreign_key_constraint(:user_id)
  end
end
