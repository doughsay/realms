defmodule Realms.Game.Exit do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "exits" do
    field :direction, :string

    belongs_to :from_room, Realms.Game.Room, foreign_key: :from_room_id, type: :binary_id
    belongs_to :to_room, Realms.Game.Room, foreign_key: :to_room_id, type: :binary_id

    timestamps(type: :utc_datetime)
  end

  @valid_directions ~w(
    north south east west
    northeast northwest southeast southwest
    up down in out
  )

  def changeset(exit, attrs) do
    exit
    |> cast(attrs, [:direction, :from_room_id, :to_room_id])
    |> validate_required([:direction, :from_room_id, :to_room_id])
    |> validate_inclusion(:direction, @valid_directions)
    |> validate_different_rooms()
    |> unique_constraint([:from_room_id, :direction],
      name: :exits_from_to_direction_unique
    )
    |> foreign_key_constraint(:from_room_id)
    |> foreign_key_constraint(:to_room_id)
  end

  defp validate_different_rooms(changeset) do
    from_id = get_field(changeset, :from_room_id)
    to_id = get_field(changeset, :to_room_id)

    if from_id && to_id && from_id == to_id do
      add_error(changeset, :to_room_id, "cannot be the same as from_room_id")
    else
      changeset
    end
  end
end
