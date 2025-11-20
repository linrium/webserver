import Config

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we can use it
# to bundle .js and .css sources.
config :webserver, Webserver.Router,
  port: 4000,
  debug_errors: true,
  code_reloader: true,
  check_origin: false,
  watchers: []

# Enable debug logging for OpenTelemetry
config :logger, :console, format: "[$level] $message\n", level: :debug

# Enable OpenTelemetry debug logging
config :logger,
  level: :debug,
  compile_time_purge_matching: [
    [level_lower_than: :debug]
  ]

# Log OpenTelemetry modules
config :logger, :console, metadata: [:otel_trace_id, :otel_span_id]
