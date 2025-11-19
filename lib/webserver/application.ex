defmodule Webserver.Application do
  use Application
  require Logger

  def start(_type, _args) do
    dispatch = [
      {:_,
       [
         {"/ws", Webserver.SocketHandler, []},
         {:_, Plug.Cowboy.Handler, {Webserver.Router, []}}
       ]}
    ]

    children = [
      %{
        id: :pg,
        start: {:pg, :start_link, []}
      },
      {Cluster.Supervisor, [Application.get_env(:libcluster, :topologies, [])]},
      Webserver.NodeMonitor,
      Webserver.KV,
      Webserver.ChatServer,
      {Plug.Cowboy,
       scheme: :http, plug: Webserver.Router, options: [port: 4000, dispatch: dispatch]}
    ]

    opts = [strategy: :one_for_one, name: Webserver.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
