**Webserver**

This repository contains an Elixir-based HTTP/message-processing server used for building high-throughput, observable services. It uses standard Elixir tooling (`mix`) and integrates with tooling and libraries for message processing (Broadway/Kafka), telemetry (OpenTelemetry / Telemetry), and an observability stack optional via Docker Compose.

**Quick Summary**
- **What it is:** An Elixir application that exposes HTTP endpoints and runs a message-processing pipeline. The code lives under `lib/webserver` and tests live in `test/`.
- **Key libraries:** `plug`, `cowboy`, `broadway`, Kafka client libraries, and OpenTelemetry integrations.
- **Extras:** A simple browser client is available at `chat_client.html` for quick manual testing.

**Quickstart — Development**
- **Prerequisites:** Elixir and Erlang/OTP installed (matching the versions in `mix.exs`). Docker/Docker Compose are optional if you want to spin up the observability stack.
- **Get dependencies:**

	`mix deps.get`

- **Compile:**

	`mix compile`

- **Run locally:**

	`mix run --no-halt`

	This starts the application using the configuration in `config/*.exs`. If the project is a Phoenix app or exposes a web server via `Plug/Cowboy`, use `iex -S mix` or `mix phx.server` as appropriate for interactive development.

- **Run tests:**

	`MIX_ENV=test mix test`

- **Run with Docker Compose (optional):**

	`docker-compose up --build`

	The repository includes a `docker/` folder with observability services (Prometheus, Grafana, Loki, Tempo). Use Docker Compose to bring that stack up alongside the app for tracing/metrics/log collection.

**Architecture Overview**
- **Core app:** The Elixir application code is in `lib/webserver`. It provides HTTP endpoints (via `Plug`/`Cowboy`) and background processing pipelines.
- **Message processing:** Broadway (and Kafka-related libraries) is used to build resilient, concurrent message processing pipelines. This makes the system suitable for ingesting high-volume streams and processing them reliably.
- **Dependencies:** Third-party dependencies are declared in `mix.exs`; vendor-like dependency directories appear under `deps/` in this workspace layout.
- **Configuration:** Environment- and runtime-specific configuration is in `config/` (`dev.exs`, `test.exs`, `prod.exs`). Check these files to see port bindings and service endpoints.
- **Observability:** OpenTelemetry + telemetry integrations are present and can export traces/metrics to the services provided under `docker/` (Prometheus, Grafana, Loki, Tempo).
- **Test and CI:** Unit tests and integration tests live under `test/`. Use `mix test` locally and integrate with your CI of choice for automated runs.

**Useful Files & Paths**
- `mix.exs`: Project definition and dependencies.
- `lib/webserver`: Application source code.
- `test`: Test suite.
- `chat_client.html`: Minimal client to exercise HTTP endpoints.
- `docker/`: Docker configs for observability stack.
- `docker-compose.yml` / `Dockerfile`: Containerization and compose orchestration for running the app and optional services.

**Development notes & tips**
- To change HTTP ports or other runtime settings, update `config/dev.exs` (or the corresponding `prod` config).
- To inspect telemetry, bring up the `docker/` stack and point Grafana / Prometheus at the exported endpoints.
- If you plan to run Kafka locally for integration testing, either use a local Kafka broker or spin one up via Docker.

- **Connecting to Docker services:** When running the observability stack or local services with Docker Compose, you may need to map hostnames to the containers' network addresses so your host (or other services) can reach them. Add entries to `/etc/hosts` if the compose setup expects fixed hostnames. For example, add lines like:

	`127.0.0.1 prometheus grafana tempo loki`

	Adjust the hostnames to match the service names used by your `docker-compose.yml` or local setup. After updating `/etc/hosts`, restart any clients (browser, CLI tools) so DNS changes take effect.

**Contributing**
- Open issues or PRs are welcome. Add tests for new behavior and follow existing coding/styles.

**Contact**
- For questions about this repository, open an issue or contact the maintainers listed in the project metadata.

