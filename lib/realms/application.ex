defmodule Realms.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      RealmsWeb.Telemetry,
      Realms.Repo,
      {DNSCluster, query: Application.get_env(:realms, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Realms.PubSub},
      # Start a worker by calling: Realms.Worker.start_link(arg)
      # {Realms.Worker, arg},
      Realms.PlayerHistoryStore,
      # Start to serve requests, typically the last entry
      RealmsWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Realms.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    RealmsWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
