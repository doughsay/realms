defmodule Realms.Game.Player do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "players" do
    field :name, :string
    field :last_seen_at, :utc_datetime
    field :current_room_id, :binary_id

    belongs_to :current_room, Realms.Game.Room,
      foreign_key: :current_room_id,
      type: :binary_id,
      define_field: false

    belongs_to :user, Realms.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(player, attrs) do
    player
    |> cast(attrs, [:id, :name, :current_room_id, :last_seen_at, :user_id])
    |> validate_required([:name, :current_room_id])
    |> validate_length(:name, min: 1, max: 100)
    |> foreign_key_constraint(:current_room_id)
    |> foreign_key_constraint(:user_id)
  end
end
