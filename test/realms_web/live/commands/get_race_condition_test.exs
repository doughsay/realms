defmodule RealmsWeb.Commands.GetRaceConditionTest do
  use RealmsWeb.ConnCase, async: false

  import Liveness
  import Phoenix.LiveViewTest
  import Realms.GameFixtures
  import RealmsWeb.GameTestHelpers

  describe "get command race conditions" do
    @tag capture_log: true
    test "only one player succeeds when multiple players try to get same item concurrently" do
      room = room_fixture()
      _sword = create_item_in_room(room, name: "sword")

      player_count = 30

      players =
        for i <- 1..player_count do
          connect_player(room: room, name: "Racer#{i}")
        end

      results =
        players
        |> Task.async_stream(
          fn %{view: view} ->
            send_command(view, "get sword")

            {success, failure} =
              eventually(fn ->
                rendered = render(view)
                text = rendered |> LazyHTML.from_fragment() |> LazyHTML.text()

                success = text =~ "You pick up sword"
                failure = text =~ "You don't see 'sword' here"

                (success || failure) && {success, failure}
              end)

            {success, failure}
          end,
          max_concurrency: player_count
        )
        |> Enum.map(fn {:ok, result} -> result end)

      successes = Enum.filter(results, fn {success, _failure} -> success end)
      failures = Enum.filter(results, fn {_success, failure} -> failure end)

      assert length(successes) == 1,
             "Expected exactly 1 success with #{player_count} concurrent attempts, got #{length(successes)}"

      assert length(failures) == player_count - 1,
             "Expected #{player_count - 1} players to fail, got #{length(failures)}"
    end

    @tag capture_log: true
    test "multiple items with multiple players - no race conditions" do
      room = room_fixture()

      # Create 5 items
      items =
        for i <- 1..5 do
          create_item_in_room(room, name: "item#{i}")
        end

      # Create 10 players
      players =
        for i <- 1..10 do
          connect_player(room: room, name: "Player#{i}")
        end

      # Each player tries to get a random item
      results =
        players
        |> Task.async_stream(
          fn %{view: view} ->
            item = Enum.random(items)
            send_command(view, "get #{item.name}")

            {success, _failure} =
              eventually(fn ->
                rendered = render(view)
                text = rendered |> LazyHTML.from_fragment() |> LazyHTML.text()

                success = text =~ "You pick up"
                failure = text =~ "You don't see"

                (success || failure) && {success, failure}
              end)

            {item.name, success}
          end,
          max_concurrency: 10
        )
        |> Enum.map(fn {:ok, result} -> result end)

      # Each item should have been picked up at most once
      results
      |> Enum.group_by(fn {item_name, _success} -> item_name end)
      |> Enum.each(fn {item_name, attempts} ->
        success_count =
          Enum.count(attempts, fn {_item_name, success} -> success end)

        assert success_count <= 1,
               "Item #{item_name} was picked up #{success_count} times (should be 0 or 1)"
      end)

      # Verify total items picked up
      total_successes = Enum.count(results, fn {_item, success} -> success end)
      assert total_successes <= 5, "At most 5 items should be picked up"
    end
  end
end
