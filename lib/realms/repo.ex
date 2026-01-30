defmodule Realms.Repo do
  use Ecto.Repo,
    otp_app: :realms,
    adapter: Ecto.Adapters.Postgres
end
