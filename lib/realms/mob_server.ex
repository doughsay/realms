defmodule Realms.MobServer do
  @moduledoc """
  Maps mob behavior strings to GenServer modules and starts mob processes.
  """

  @behavior_modules %{
    "tim_the_retired_adventurer" => Realms.MobBehaviors.TimTheRetiredAdventurer
  }

  @doc """
  Returns the GenServer module for a given behavior string.
  """
  def behavior_module(behavior) do
    Map.fetch(@behavior_modules, behavior)
  end

  @doc """
  Starts a mob process under `Realms.MobSupervisor` using the behavior module
  determined by the mob's `behavior` field.
  """
  def start_mob(%{id: id, behavior: behavior} = _mob) do
    case behavior_module(behavior) do
      {:ok, module} ->
        DynamicSupervisor.start_child(Realms.MobSupervisor, {module, id})

      :error ->
        {:error, {:unknown_behavior, behavior}}
    end
  end
end
