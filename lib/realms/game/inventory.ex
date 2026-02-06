defmodule Realms.Game.Inventory do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "inventories" do
    has_many :items, Realms.Game.Item, foreign_key: :location_id

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(inventory, attrs) do
    inventory
    |> cast(attrs, [])
  end
end
