import Config

if System.get_env("PHX_SERVER") do
  config :webserver, Webserver.Router, server: true
end

if config_env() == :prod do
  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but to
  # be safe we also include a default here.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :webserver, Webserver.Router,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/plug_cowboy/Plug.Cowboy.html
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  # ## Configuring the Release
  #
  # If you are doing OTP releases, you need to instruct Phoenix
  # to start each relevant endpoint:
  #
  #     config :webserver, Webserver.Router, server: true
  #
  # Then you can assemble a release by calling `mix release`.
  # See `mix help release` for more information.

  topologies =
    case System.get_env("LIBCLUSTER_STRATEGY") do
      "gossip" ->
        [
          k8s: [
            strategy: Cluster.Strategy.Gossip
          ]
        ]

      _ ->
        [
          k8s: [
            strategy: Cluster.Strategy.Kubernetes,
            config: [
              mode: :ip,
              kubernetes_node_basename: "webserver",
              kubernetes_selector: "app=webserver",
              polling_interval: 3_000
            ]
          ]
        ]
    end

  config :libcluster, topologies: topologies
end
