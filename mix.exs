defmodule Webserver.MixProject do
  use Mix.Project

  def project do
    [
      app: :webserver,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Webserver.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:plug_cowboy, "~> 2.7.5"},
      {:libcluster, "~> 3.5.0"},
      {:jason, "~> 1.4.4"},
      {:ecto, "~> 3.10"},
      {:open_api_spex, "~> 3.21"},
      {:scalar_plug, "~> 0.2.0"},
      # OpenTelemetry
      {:opentelemetry, "~> 1.5"},
      {:opentelemetry_exporter, "~> 1.8"},
      {:opentelemetry_api, "~> 1.4"},
      {:opentelemetry_cowboy, "~> 0.3"},
      {:opentelemetry_telemetry, "~> 1.1"}
    ]
  end
end
