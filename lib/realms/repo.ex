defmodule Realms.Repo do
  use Ecto.Repo,
    otp_app: :realms,
    adapter: Ecto.Adapters.Postgres

  @doc """
  Fetches a single entry from the queryable by its primary key.
  Returns `{:ok, struct}` if found, `{:error, error_tag}` otherwise.

  ## Options
    * `:error_tag` - The error atom to return if not found. Defaults to `:not_found`.
    * Other options are passed to `Ecto.Repo.get/3`.
  """
  def fetch(queryable, id, opts \\ []) do
    {error_tag, opts} = Keyword.pop(opts, :error_tag, :not_found)

    case get(queryable, id, opts) do
      nil -> {:error, error_tag}
      struct -> {:ok, struct}
    end
  end

  @doc """
  Fetches a single entry from the queryable matching the given clauses.
  Returns `{:ok, struct}` if found, `{:error, error_tag}` otherwise.

  ## Options
    * `:error_tag` - The error atom to return if not found. Defaults to `:not_found`.
    * Other options are passed to `Ecto.Repo.get_by/3`.
  """
  def fetch_by(queryable, clauses, opts \\ []) do
    {error_tag, opts} = Keyword.pop(opts, :error_tag, :not_found)

    case get_by(queryable, clauses, opts) do
      nil -> {:error, error_tag}
      struct -> {:ok, struct}
    end
  end

  @doc """
  Fetches a single entry from the queryable.
  Returns `{:ok, struct}` if found, `{:error, error_tag}` otherwise.

  ## Options
    * `:error_tag` - The error atom to return if not found. Defaults to `:not_found`.
    * Other options are passed to `Ecto.Repo.one/2`.
  """
  def fetch_one(queryable, opts \\ []) do
    {error_tag, opts} = Keyword.pop(opts, :error_tag, :not_found)

    case one(queryable, opts) do
      nil -> {:error, error_tag}
      struct -> {:ok, struct}
    end
  end
end
