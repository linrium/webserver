defmodule Webserver.Application do
  use Application
  require Logger

  def start(_type, _args) do
    # Setup custom telemetry handlers for OpenTelemetry
    :opentelemetry_cowboy.setup()
    Webserver.Telemetry.setup()

    dispatch = [
      {:_,
       [
         {"/ws", Webserver.Web.SocketHandler, []},
         {:_, Plug.Cowboy.Handler, {Webserver.Web.Router, []}}
       ]}
    ]

    children = [
      %{
        id: :pg,
        start: {:pg, :start_link, []}
      },
      {Cluster.Supervisor, [Application.get_env(:libcluster, :topologies, [])]},
      Webserver.Services.NodeMonitor,
      Webserver.Services.KV,
      Webserver.Services.ChatServer,
      Webserver.Kafka.Consumer,
      {Plug.Cowboy,
       scheme: :http, plug: Webserver.Web.Router, options: [port: 4000, dispatch: dispatch]}
    ]

    opts = [strategy: :one_for_one, name: Webserver.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
