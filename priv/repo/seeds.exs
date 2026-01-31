# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#

alias Realms.Game

# Clear existing data
Realms.Repo.delete_all(Realms.Game.Exit)
Realms.Repo.delete_all(Realms.Game.Room)

IO.puts("Creating rooms...")

# Create rooms
{:ok, town_square} =
  Game.create_room(%{
    name: "Town Square",
    description:
      "A bustling town square with a fountain at its center. Cobblestone paths lead in several directions, and the sound of merchants hawking their wares fills the air. To the north, you can see the warm glow of the tavern. To the east stands an old stone well, and to the west is the general store."
  })

{:ok, tavern} =
  Game.create_room(%{
    name: "The Prancing Pony Tavern",
    description:
      "A cozy tavern with the smell of ale and roasted meats filling the air. Patrons laugh and share stories around worn wooden tables. The bartender polishes glasses behind the bar, and a warm fire crackles in the hearth. The exit south leads back to the town square."
  })

{:ok, old_well} =
  Game.create_room(%{
    name: "The Old Well",
    description:
      "An ancient stone well sits here, its depths dark and mysterious. The stonework is weathered but solid, and you can hear the faint echo of water far below. A rope ladder descends into the darkness. The town square lies to the west."
  })

{:ok, general_store} =
  Game.create_room(%{
    name: "General Store",
    description:
      "Shelves line the walls of this well-stocked store, filled with supplies for adventurers and townsfolk alike. The shopkeeper stands behind a counter, ready to assist customers. A sign reads 'We buy and sell adventuring goods!' The door east leads back to the town square."
  })

{:ok, well_bottom} =
  Game.create_room(%{
    name: "Bottom of the Well",
    description:
      "You stand at the bottom of the well, knee-deep in cold water. The walls are slick with moss, and the air is damp and cool. Far above, you can see a circle of daylight. To the east, you notice a dark tunnel entrance that seems to have been carved into the well's foundation."
  })

{:ok, secret_tunnel} =
  Game.create_room(%{
    name: "Secret Tunnel",
    description:
      "A narrow tunnel carved through the bedrock. The walls are rough and unfinished, suggesting this passage was made in secret. Water drips from the ceiling, and the air is musty. The tunnel slopes upward to the east, while the well lies back to the west."
  })

{:ok, hidden_chamber} =
  Game.create_room(%{
    name: "Hidden Chamber",
    description:
      "A small, secret chamber hidden beneath the town. Ancient runes are carved into the walls, still faintly glowing with an otherworldly light. In the center of the room sits a stone pedestal, though whatever once rested upon it is long gone. The tunnel continues west back toward the well."
  })

IO.puts("Creating exits...")

# Connect rooms with bidirectional exits
{:ok, _} = Game.create_bidirectional_exit(town_square.id, tavern.id, "north", "south")
{:ok, _} = Game.create_bidirectional_exit(town_square.id, old_well.id, "east", "west")
{:ok, _} = Game.create_bidirectional_exit(town_square.id, general_store.id, "west", "east")
{:ok, _} = Game.create_bidirectional_exit(old_well.id, well_bottom.id, "down", "up")
{:ok, _} = Game.create_bidirectional_exit(well_bottom.id, secret_tunnel.id, "east", "west")
{:ok, _} = Game.create_bidirectional_exit(secret_tunnel.id, hidden_chamber.id, "east", "west")

IO.puts("Seed data created successfully!")
IO.puts("\nCreated rooms:")
IO.puts("- Town Square (central hub)")
IO.puts("- The Prancing Pony Tavern (north of square)")
IO.puts("- The Old Well (east of square)")
IO.puts("- General Store (west of square)")
IO.puts("- Bottom of the Well (down from well)")
IO.puts("- Secret Tunnel (east from well bottom)")
IO.puts("- Hidden Chamber (east from tunnel)")
