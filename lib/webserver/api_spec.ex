defmodule Webserver.ApiSpec do
  @moduledoc """
  OpenAPI specification for the Webserver API.
  """
  alias OpenApiSpex.{Components, Info, OpenApi, Server}
  @behaviour OpenApi

  @impl OpenApi
  def spec do
    %OpenApi{
      info: %Info{
        title: "Distributed Webserver API",
        version: "0.1.0",
        description: """
        A distributed Elixir webserver with:
        - Key-Value store distributed across cluster nodes
        - Real-time chat via WebSockets
        - Node discovery and monitoring
        """
      },
      servers: [
        %Server{
          url: "http://localhost:4000",
          description: "Development server"
        }
      ],
      # Manually define paths since we're using Plug.Router, not Phoenix
      paths: %{
        "/" => %OpenApiSpex.PathItem{
          get: Webserver.Operations.HealthCheck.operation()
        },
        "/nodes" => %OpenApiSpex.PathItem{
          get: Webserver.Operations.ListNodes.operation()
        },
        "/kv" => %OpenApiSpex.PathItem{
          post: Webserver.Operations.PutKV.operation()
        },
        "/kv/{key}" => %OpenApiSpex.PathItem{
          get: Webserver.Operations.GetKV.operation()
        }
      }
    }
    |> OpenApiSpex.resolve_schema_modules()
  end
end
