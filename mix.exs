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
      {:ecto, "~> 3.10"}
    ]
  end
end
