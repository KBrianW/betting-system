defmodule BettingSystem.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      BettingSystemWeb.Telemetry,
      BettingSystem.Repo,
      {DNSCluster, query: Application.get_env(:betting_system, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: BettingSystem.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: BettingSystem.Finch},
      # Start a worker by calling: BettingSystem.Worker.start_link(arg)
      # {BettingSystem.Worker, arg},
      # Start to serve requests, typically the last entry
      BettingSystemWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: BettingSystem.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    BettingSystemWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
