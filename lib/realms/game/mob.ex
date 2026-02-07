defmodule Realms.Game.Mob do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "mobs" do
    field :name, :string
    field :long_name, :string
    field :description, :string
    field :behavior, :string

    belongs_to :current_room, Realms.Game.Room,
      foreign_key: :current_room_id,
      type: :binary_id

    belongs_to :inventory, Realms.Game.Inventory

    timestamps(type: :utc_datetime)
  end

  def changeset(mob, attrs) do
    mob
    |> cast(attrs, [:name, :long_name, :description, :behavior, :current_room_id, :inventory_id])
    |> validate_required([:name, :long_name, :description, :behavior, :current_room_id])
    |> foreign_key_constraint(:current_room_id)
    |> foreign_key_constraint(:inventory_id)
  end
end
