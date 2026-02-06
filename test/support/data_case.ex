defmodule Realms.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use Realms.DataCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Liveness
      import Realms.DataCase

      alias Realms.Repo
    end
  end

  setup tags do
    Realms.DataCase.setup_db(tags)
    :ok
  end

  @doc """
  Sets up the database by truncating tables.

  NOTE: Any new tables added to the application must be included in the TRUNCATE
  statement for this function to work properly.
  """
  def setup_db(_tags) do
    Ecto.Adapters.SQL.query!(
      Realms.Repo,
      "TRUNCATE users, users_tokens, rooms, exits, players, items, inventories, item_contents CASCADE"
    )

    :ok
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
