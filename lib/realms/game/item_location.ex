defmodule Realms.Game.ItemLocation do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key false
  @foreign_key_type :binary_id

  schema "item_locations" do
    belongs_to :item, Realms.Game.Item, primary_key: true
    belongs_to :inventory, Realms.Game.Inventory, primary_key: false

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(item_location, attrs) do
    item_location
    |> cast(attrs, [:item_id, :inventory_id])
    |> validate_required([:item_id, :inventory_id])
    |> foreign_key_constraint(:item_id)
    |> foreign_key_constraint(:inventory_id)
  end
end
