defmodule Realms.Commands.Utils do
  @moduledoc """
  Shared utilities for command modules.
  """

  @doc """
  Finds an item in a list by matching the search term against the prefix of any
  word in the item's name. Case-insensitive.

  Returns {:ok, item} if found, or {:error, :no_matching_item} if not found.
  """
  def match_item(items, search_term) do
    search_term = String.downcase(search_term)

    Enum.find_value(items, {:error, :no_matching_item}, fn item ->
      match? =
        item.name
        |> String.downcase()
        |> String.split()
        |> Enum.any?(fn word -> String.starts_with?(word, search_term) end)

      if match?, do: {:ok, item}
    end)
  end
end
