# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#

alias Realms.Game

# Clear existing data
IO.puts("Clearing existing data...")
Realms.Repo.delete_all(Realms.Game.Player)
Realms.Repo.delete_all(Realms.Game.Mob)
Realms.Repo.delete_all(Realms.Game.Exit)
Realms.Repo.delete_all(Realms.Game.Room)
Realms.Repo.delete_all(Realms.Game.Item)

rooms = %{
  town_square: %{
    name: "Town Square",
    description:
      "A bustling town square with a fountain at its center. Cobblestone paths lead in several directions, and the sound of merchants hawking their wares fills the air. To the north, you can see the warm glow of the tavern. To the east stands an old stone well, and to the west is the general store."
  },
  tavern: %{
    name: "The Prancing Pony Tavern",
    description:
      "A cozy tavern with the smell of ale and roasted meats filling the air. Patrons laugh and share stories around worn wooden tables. The bartender polishes glasses behind the bar, and a warm fire crackles in the hearth. The exit south leads back to the town square."
  },
  general_store: %{
    name: "General Store",
    description:
      "Shelves line the walls of this well-stocked store, filled with supplies for adventurers and townsfolk alike. The shopkeeper stands behind a counter, ready to assist customers. A sign reads 'We buy and sell adventuring goods!' The door east leads back to the town square."
  },
  old_well: %{
    name: "The Old Well",
    description:
      "An ancient stone well sits here, its depths dark and mysterious. The stonework is weathered but solid, and you can hear the faint echo of water far below. A rope ladder descends into the darkness. The town square lies to the west."
  },
  well_bottom: %{
    name: "Bottom of the Well",
    description:
      "You stand at the bottom of the well, knee-deep in cold water. The walls are slick with moss, and the air is damp and cool. Far above, you can see a circle of daylight. To the east, you notice a dark tunnel entrance that seems to have been carved into the well's foundation."
  },
  secret_tunnel: %{
    name: "Secret Tunnel",
    description:
      "A narrow tunnel carved through the bedrock. The walls are rough and unfinished, suggesting this passage was made in secret. Water drips from the ceiling, and the air is musty. The tunnel slopes upward to the east, while the well lies back to the west."
  },
  hidden_chamber: %{
    name: "Hidden Chamber",
    description:
      "A small, secret chamber hidden beneath the town. Ancient runes are carved into the walls, still faintly glowing with an otherworldly light. In the center of the room sits a stone pedestal, though whatever once rested upon it is long gone. The tunnel continues west back toward the well."
  }
}

IO.puts("Creating rooms...")

room_ids =
  for {key, room_no_id} <- rooms, into: %{} do
    {:ok, room} = Game.create_room(room_no_id)
    {key, room.id}
  end

IO.puts("Creating exits...")

links =
  [
    {:town_square, :tavern, "north", "south"},
    {:town_square, :old_well, "east", "west"},
    {:town_square, :general_store, "west", "east"},
    {:old_well, :well_bottom, "down", "up"},
    {:well_bottom, :secret_tunnel, "east", "west"},
    {:secret_tunnel, :hidden_chamber, "east", "west"}
  ]

for {id1, id2, dir1, dir2} <- links do
  {:ok, _} = Game.create_bidirectional_exit(room_ids[id1], room_ids[id2], dir1, dir2)
end

IO.puts("Creating items...")

items = [
  # Town Square
  %{
    name: "Rusty Dagger",
    description: "An old dagger, pitted with rust but still sharp enough to cut.",
    location: :town_square
  },
  # Tavern
  %{
    name: "Wooden Tankard",
    description: "A heavy wooden tankard, stained with years of spilled ale.",
    location: :tavern
  },
  # General Store
  %{
    name: "Rope",
    description: "A coil of sturdy hemp rope, essential for any adventurer.",
    location: :general_store
  },
  %{
    name: "Torch",
    description: "A wooden stick wrapped in oil-soaked rags.",
    location: :general_store
  },
  # Old Well
  %{
    name: "Shiny Coin",
    description: "A single gold coin, gleaming in the dirt.",
    location: :old_well
  },
  # Hidden Chamber
  %{
    name: "Ancient Scroll",
    description: "A crumbling scroll covered in indecipherable runes.",
    location: :hidden_chamber
  }
]

# Create regular items
for item_data <- items do
  location_id = room_ids[item_data.location]
  room = Game.get_room!(location_id)

  {:ok, item} =
    Game.create_item(
      Map.put(
        Map.take(item_data, [:name, :description]),
        :location_id,
        room.inventory_id
      )
    )

  IO.puts("Created item: #{item.name} in #{room.name}")
end

# Create a container item (Backpack) in the Town Square
town_square = Game.get_room!(room_ids[:town_square])

{:ok, backpack} =
  Game.create_item(
    %{
      name: "Leather Backpack",
      description: "A worn leather backpack with plenty of pockets.",
      location_id: town_square.inventory_id
    },
    has_inventory: true
  )

IO.puts("Created container: #{backpack.name} in #{town_square.name}")

# Create items inside the Backpack
backpack_contents = [
  %{
    name: "Apple",
    description: "A red, juicy apple. Looks delicious."
  },
  %{
    name: "Map",
    description: "A crude map of the local area."
  }
]

backpack_inventory_id = Game.get_container_inventory_id(backpack)

for content_data <- backpack_contents do
  {:ok, item} = Game.create_item(Map.put(content_data, :location_id, backpack_inventory_id))
  IO.puts("Created item: #{item.name} inside #{backpack.name}")
end

IO.puts("Creating mobs...")

{:ok, tim} =
  Game.create_mob(%{
    name: "Tim",
    long_name: "Tim the \"Retired\" Adventurer",
    description:
      "A wiry old man with one arm, a permanently singed eyebrow, and a look in his eyes that suggests he's seen things he probably shouldn't have survived. His battered armor is held together mostly by optimism and twine.",
    behavior: "tim_the_retired_adventurer",
    current_room_id: room_ids[:town_square]
  })

IO.puts("Created mob: #{tim.name} in Town Square")

for {_, room} <- rooms do
  IO.puts("Created room: #{room.name}")
end
