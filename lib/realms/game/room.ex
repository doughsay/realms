defmodule Realms.Game.Room do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "rooms" do
    field :name, :string
    field :description, :string

    has_many :exits_from, Realms.Game.Exit, foreign_key: :from_room_id
    has_many :exits_to, Realms.Game.Exit, foreign_key: :to_room_id
    has_many :players, Realms.Game.Player, foreign_key: :current_room_id

    belongs_to :inventory, Realms.Game.Inventory

    timestamps(type: :utc_datetime)
  end

  def changeset(room, attrs) do
    room
    |> cast(attrs, [:name, :description, :inventory_id])
    |> validate_required([:name, :description, :inventory_id])
    |> validate_length(:name, min: 1, max: 255)
    |> validate_length(:description, min: 1, max: 5000)
  end
end
