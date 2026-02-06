defmodule RealmsWeb.GameTestHelpers do
  @moduledoc """
  Helpers for Game LiveView integration tests.
  """

  import Phoenix.LiveViewTest
  import ExUnit.Assertions
  import Liveness

  @doc """
  Sends a command via the game form.
  """
  def send_command(view, command) do
    view
    |> form("#command-form", command: %{command: command})
    |> render_submit()

    view
  end

  @doc """
  Asserts that the view eventually contains the expected content.
  """
  def assert_eventual_output(view, expected_content, timeout \\ 1000) do
    assert eventually(fn -> render(view) =~ expected_content end, timeout)
    view
  end
end
