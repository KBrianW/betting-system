defmodule BetZone.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      BetZoneWeb.Telemetry,
      BetZone.Repo,
      {DNSCluster, query: Application.get_env(:bet_zone, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: BetZone.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: BetZone.Finch},
      # Start a worker by calling: BetZone.Worker.start_link(arg)
      # {BetZone.Worker, arg},
      # Start to serve requests, typically the last entry
      BetZoneWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: BetZone.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    BetZoneWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
