import Config
config :ohio_elixir, Oban, testing: :manual
config :ohio_elixir, token_signing_secret: "txoKmnSSOKkikRibOJQOYEsdLeQ3MDq5"
config :bcrypt_elixir, log_rounds: 1
config :ash, policies: [show_policy_breakdowns?: true], disable_async?: true

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :ohio_elixir, OhioElixir.Repo,
  database: Path.expand("../ohio_elixir_test.db", __DIR__),
  pool_size: 5,
  pool: Ecto.Adapters.SQL.Sandbox

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :ohio_elixir, OhioElixirWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "ZO2LKUp/SGXnJlNWZeMbGnC8Rv9prUiSyv19jcirQm1rjML6sppMBQNQtaq8wUBo",
  server: false

# In test we don't send emails
config :ohio_elixir, OhioElixir.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true

# OG image HMAC secret for tests
config :ohio_elixir, :og_image, hmac_secret: "test-secret"
