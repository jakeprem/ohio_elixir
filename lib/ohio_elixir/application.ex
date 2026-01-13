defmodule OhioElixir.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      OhioElixirWeb.Telemetry,
      OhioElixir.Repo,
      {OhioElixir.RateLimiter, clean_period: :timer.minutes(1)},
      {Ecto.Migrator,
       repos: Application.fetch_env!(:ohio_elixir, :ecto_repos), skip: skip_migrations?()},
      {Oban,
       AshOban.config(
         Application.fetch_env!(:ohio_elixir, :ash_domains),
         Application.fetch_env!(:ohio_elixir, Oban)
       )},
      # Start a worker by calling: OhioElixir.Worker.start_link(arg)
      # {OhioElixir.Worker, arg},
      # Start to serve requests, typically the last entry
      {DNSCluster, query: Application.get_env(:ohio_elixir, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: OhioElixir.PubSub},
      OhioElixirWeb.Endpoint,
      {AshAuthentication.Supervisor, [otp_app: :ohio_elixir]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: OhioElixir.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    OhioElixirWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp skip_migrations?() do
    # By default, sqlite migrations are run when using a release
    System.get_env("RELEASE_NAME") == nil
  end
end
