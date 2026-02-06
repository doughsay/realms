defmodule Realms.Game.Item do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "items" do
    field :name, :string
    field :description, :string

    belongs_to :location, Realms.Game.Inventory, foreign_key: :location_id

    has_one :item_content, Realms.Game.ItemContent
    has_one :inventory, through: [:item_content, :inventory]

    timestamps(type: :utc_datetime)
  end

  def changeset(item, attrs) do
    item
    |> cast(attrs, [:name, :description, :location_id])
    |> validate_required([:name, :location_id])
  end
end
