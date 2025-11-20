import Config

config :webserver,
  generators: [timestamp_type: :utc_datetime]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :webserver, :kafka,
  brokers: [localhost: 9092],
  group_id: "webserver_consumer_group",
  topics: ["webserver_input"]

# Import OpenTelemetry configuration
import_config "opentelemetry.exs"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
