import Config

# OpenTelemetry Configuration
config :opentelemetry,
  # Span processor configuration
  span_processor: :batch,
  # Traces exporter configuration
  traces_exporter: :otlp,
  # Enable debug logging
  text_map_propagators: [:trace_context, :baggage],
  # Log all spans for debugging
  processors: [
    {:otel_batch_processor,
     %{
       exporter: {:opentelemetry_exporter, :otlp}
     }}
  ]

# OTLP Exporter configuration
config :opentelemetry_exporter,
  otlp_protocol: :http_protobuf,
  otlp_endpoint: "http://localhost:4318",
  otlp_headers: [],
  otlp_compression: :gzip

# Resource attributes
config :opentelemetry, :resource,
  service: [
    name: "webserver",
    namespace: "elixir"
  ]
