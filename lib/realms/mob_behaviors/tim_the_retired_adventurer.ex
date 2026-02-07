defmodule Realms.MobBehaviors.TimTheRetiredAdventurer do
  @moduledoc """
  GenServer for Tim the "Retired" Adventurer.

  Every 30 seconds or so, Tim tells an outlandish story to whoever
  happens to be in the room.
  """

  use GenServer

  alias Realms.Game
  alias Realms.Messaging

  require Logger

  @story_interval to_timeout(second: 30)

  @stories [
    "Did I ever tell you about the time I defeated a dragon with nothing but a wooden spoon? Swallowed me whole, it did. Had to tickle its uvula from the inside.",
    "I once arm-wrestled a hill giant for three days straight. Won, too. 'Course, that's the arm I lost. Worth it though — you should've seen the look on his face.",
    "Back in my day, I swam across the Boiling Sea. Twice. The second time was just to fetch my hat.",
    "You know how I lost this arm? Lent it to a lich who promised to give it back. Never trust the undead with your belongings.",
    "I once talked a mimic out of eating me. We're pen pals now. Well, it's a pen pal — it ate the pen.",
    "People say you can't outrun a fireball. Those people never owed money to a wizard.",
    "I used to have a pet basilisk. Lovely creature. Terrible at hide and seek, though — kept turning the other players to stone.",
    "I once fell off the edge of the world. Landed on something soft. Turned out to be another world. Fell off that one too.",
    "The secret to surviving a hundred adventures? Always carry a spare pair of trousers. Don't ask why. You'll find out.",
    "I challenged Death to a game of cards once. Won three hands. Lost the fourth and my left kneecap. It grew back, mostly."
  ]

  def child_spec(mob_id) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [mob_id]},
      restart: :transient
    }
  end

  def start_link(mob_id) do
    GenServer.start_link(__MODULE__, mob_id, name: via_tuple(mob_id))
  end

  @impl true
  def init(mob_id) do
    Logger.info("TimTheRetiredAdventurer started for mob #{mob_id}")
    schedule_story()
    {:ok, %{mob_id: mob_id}}
  end

  @impl true
  def handle_info(:tell_story, state) do
    mob = Game.get_mob!(state.mob_id)
    story = Enum.random(@stories)

    Messaging.send_to_room(
      mob.current_room_id,
      "<bright-yellow>Tim</><gray> says: </><white>#{story}</>"
    )

    schedule_story()
    {:noreply, state}
  end

  defp schedule_story do
    jitter = :rand.uniform(to_timeout(second: 10))
    Process.send_after(self(), :tell_story, @story_interval + jitter)
  end

  defp via_tuple(mob_id) do
    {:via, Registry, {Realms.MobRegistry, mob_id}}
  end
end
