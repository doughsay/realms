defmodule Realms.Game.Inventory do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "inventories" do
    has_many :item_locations, Realms.Game.ItemLocation
    has_many :items, through: [:item_locations, :item]

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(inventory, attrs) do
    inventory
    |> cast(attrs, [])
  end
end
