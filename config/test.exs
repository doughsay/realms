import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used

# In test we don't send emails
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :realms, Realms.Mailer, adapter: Swoosh.Adapters.Test

config :realms, Realms.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "realms_test#{System.get_env("MIX_TEST_PARTITION")}",
  # We don't run a server during test. If one is required,
  # you can enable the server option below.
  pool_size: System.schedulers_online() * 2

config :realms, RealmsWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "Z/J2awuXb/i8D+a7wQjjFbtJYxH87uxOdl7Kowql/XFUUJN5xfN2eJnLmRaU2VLH",
  server: false

# Disable welcome banner, auto-look on join, and command echo for tests
config :realms,
  show_welcome_banner: false,
  auto_look_on_join: false,
  echo_commands: false

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false
