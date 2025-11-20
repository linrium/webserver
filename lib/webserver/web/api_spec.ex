defmodule Webserver.Web.ApiSpec do
  @moduledoc """
  OpenAPI specification for the Webserver API.
  """
  alias OpenApiSpex.{Info, OpenApi, Server}
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
          get: Webserver.Web.Controllers.HealthController.open_api_operation(:index)
        },
        "/nodes" => %OpenApiSpex.PathItem{
          get: Webserver.Web.Controllers.NodeController.open_api_operation(:index)
        },
        "/kv" => %OpenApiSpex.PathItem{
          post: Webserver.Web.Controllers.KVController.open_api_operation(:put)
        },
        "/kv/{key}" => %OpenApiSpex.PathItem{
          get: Webserver.Web.Controllers.KVController.open_api_operation(:get)
        }
      }
    }
    |> OpenApiSpex.resolve_schema_modules()
  end
end
