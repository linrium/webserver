# OpenAPI Spec Integration Guide

This guide explains how to integrate `open_api_spex` into the webserver project to automatically generate OpenAPI specifications for your API endpoints.

## Overview

`open_api_spex` is an Elixir library that helps you:
- Generate OpenAPI 3.0 specifications from your code
- Validate request/response payloads against schemas
- Serve interactive Swagger UI documentation
- Export specs as JSON/YAML files

## Installation

### 1. Add Dependencies

Add `open_api_spex` to your `mix.exs`:

```elixir
defp deps do
  [
    {:plug_cowboy, "~> 2.7.5"},
    {:libcluster, "~> 3.5.0"},
    {:jason, "~> 1.4.4"},
    {:ecto, "~> 3.10"},
    {:open_api_spex, "~> 3.21"}  # Add this line
  ]
end
```

### 2. Install Dependencies

```bash
mix deps.get
```

### 3. Update Formatter Configuration

Create or update `.formatter.exs` to prevent automatic parentheses on OpenAPI macros:

```elixir
[
  import_deps: [:ecto, :open_api_spex],
  inputs: ["*.{ex,exs}", "{config,lib,test}/**/*.{ex,exs}"]
]
```

## Implementation Steps

### Step 1: Create API Spec Module

Create `lib/webserver/api_spec.ex`:

```elixir
defmodule Webserver.ApiSpec do
  @moduledoc """
  OpenAPI specification for the Webserver API.
  """
  alias OpenApiSpex.{Components, Info, OpenApi, Paths, SecurityScheme, Server}
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
      paths: %Paths{
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
      },
      components: %Components{
        schemas: %{
          "KVRequest" => Webserver.Schemas.KVRequest,
          "KVResponse" => Webserver.Schemas.KVResponse,
          "KVGetResponse" => Webserver.Schemas.KVGetResponse,
          "NodesResponse" => Webserver.Schemas.NodesResponse,
          "ErrorResponse" => Webserver.Schemas.ErrorResponse
        }
      }
    }
    |> OpenApiSpex.resolve_schema_modules()
  end
end
```

### Step 2: Define Schemas

Create `lib/webserver/schemas.ex`:

```elixir
defmodule Webserver.Schemas do
  @moduledoc """
  OpenAPI schemas for request/response bodies.
  """
  alias OpenApiSpex.Schema

  defmodule KVRequest do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "KVRequest",
      description: "Request body for storing a key-value pair",
      type: :object,
      properties: %{
        key: %Schema{type: :string, description: "The key to store", example: "user:123"},
        value: %Schema{type: :string, description: "The value to store", example: "John Doe"}
      },
      required: [:key, :value]
    })
  end

  defmodule KVResponse do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "KVResponse",
      description: "Response after storing a key-value pair",
      type: :object,
      properties: %{
        status: %Schema{type: :string, description: "Operation status", example: "ok"},
        node: %Schema{type: :string, description: "Node that handled the request", example: "webserver@127.0.0.1"}
      },
      required: [:status, :node]
    })
  end

  defmodule KVGetResponse do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "KVGetResponse",
      description: "Response when retrieving a value",
      type: :object,
      properties: %{
        value: %Schema{type: :string, description: "The stored value", example: "John Doe"},
        from_node: %Schema{type: :string, description: "Node where value was found", example: "webserver@127.0.0.1"}
      },
      required: [:value, :from_node]
    })
  end

  defmodule NodesResponse do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "NodesResponse",
      description: "List of nodes in the cluster",
      type: :object,
      properties: %{
        nodes: %Schema{
          type: :array,
          items: %Schema{type: :string},
          description: "Array of node names in the cluster",
          example: ["webserver@127.0.0.1", "webserver@10.0.1.2"]
        }
      },
      required: [:nodes]
    })
  end

  defmodule ErrorResponse do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "ErrorResponse",
      description: "Error response",
      type: :object,
      properties: %{
        error: %Schema{type: :string, description: "Error message"},
        errors: %Schema{
          type: :object,
          description: "Validation errors",
          additionalProperties: %Schema{
            type: :array,
            items: %Schema{type: :string}
          }
        }
      }
    })
  end
end
```

### Step 3: Define Operations

Create `lib/webserver/operations.ex`:

```elixir
defmodule Webserver.Operations do
  @moduledoc """
  OpenAPI operation definitions for each endpoint.
  """
  alias OpenApiSpex.{Operation, Response, RequestBody}
  alias Webserver.Schemas

  defmodule HealthCheck do
    @moduledoc false
    def operation do
      %Operation{
        tags: ["Health"],
        summary: "Health check",
        description: "Returns a simple health check message",
        operationId: "HealthCheck.get",
        responses: %{
          200 => Response.new("Success", "text/plain", nil, example: "Hello World")
        }
      }
    end
  end

  defmodule ListNodes do
    @moduledoc false
    def operation do
      %Operation{
        tags: ["Cluster"],
        summary: "List cluster nodes",
        description: "Returns a list of all nodes in the distributed cluster",
        operationId: "ListNodes.get",
        responses: %{
          200 => Response.new("Nodes list", "application/json", Schemas.NodesResponse)
        }
      }
    end
  end

  defmodule PutKV do
    @moduledoc false
    def operation do
      %Operation{
        tags: ["Key-Value Store"],
        summary: "Store a key-value pair",
        description: "Stores a key-value pair in the distributed KV store",
        operationId: "PutKV.post",
        requestBody: RequestBody.new("KV pair to store", "application/json", Schemas.KVRequest, required: true),
        responses: %{
          200 => Response.new("Success", "application/json", Schemas.KVResponse),
          400 => Response.new("Validation error", "application/json", Schemas.ErrorResponse)
        }
      }
    end
  end

  defmodule GetKV do
    @moduledoc false
    def operation do
      %Operation{
        tags: ["Key-Value Store"],
        summary: "Retrieve a value by key",
        description: "Retrieves a value from the distributed KV store by searching all cluster nodes",
        operationId: "GetKV.get",
        parameters: [
          Operation.parameter(:key, :path, :string, "The key to retrieve", required: true, example: "user:123")
        ],
        responses: %{
          200 => Response.new("Value found", "application/json", Schemas.KVGetResponse),
          404 => Response.new("Key not found", "application/json", Schemas.ErrorResponse)
        }
      }
    end
  end
end
```

### Step 4: Update Router

Modify `lib/webserver/router.ex` to serve the OpenAPI spec:

```elixir
defmodule Webserver.Router do
  use Plug.Router

  plug(Plug.Parsers, parsers: [:json], json_decoder: Jason)
  
  # Add OpenAPI spec plug
  plug(OpenApiSpex.Plug.PutApiSpec, module: Webserver.ApiSpec)
  
  plug(:match)
  plug(:dispatch)

  # Serve OpenAPI spec as JSON
  get "/api/openapi" do
    conn
    |> OpenApiSpex.Plug.RenderSpec.call([])
  end

  # Serve Swagger UI
  get "/swaggerui" do
    conn
    |> OpenApiSpex.Plug.SwaggerUI.call(path: "/api/openapi")
  end

  # ... rest of your existing routes ...
end
```

### Step 5: Generate Spec File (Optional)

You can generate a static OpenAPI spec file:

```bash
# Generate JSON spec
mix openapi.spec.json --spec Webserver.ApiSpec --pretty

# Generate YAML spec (requires ymlr dependency)
mix openapi.spec.yaml --spec Webserver.ApiSpec
```

The spec will be written to `priv/static/openapi.json` or `priv/static/openapi.yaml`.

## Usage

### View Interactive Documentation

1. Start your server: `mix run --no-halt`
2. Open browser to: `http://localhost:4000/swaggerui`
3. You'll see an interactive Swagger UI with all your endpoints documented

### Access Raw Spec

Visit `http://localhost:4000/api/openapi` to get the raw OpenAPI JSON specification.

## Request/Response Validation (Optional)

You can add automatic request/response validation:

```elixir
# In your router, add validation plugs
plug(OpenApiSpex.Plug.CastAndValidate, json_render_error_v2: true)

# This will automatically:
# - Validate incoming requests against schemas
# - Cast parameters to correct types
# - Return 400 errors for invalid requests
```

## Advanced: Custom Response Validation

To validate responses in development:

```elixir
# config/dev.exs
config :webserver, Webserver.Router,
  validate_responses: true

# Then in your router
if Application.get_env(:webserver, __MODULE__)[:validate_responses] do
  plug(OpenApiSpex.Plug.ValidateResponse)
end
```

## Benefits for Your Project

1. **Auto-generated Documentation**: Your API docs stay in sync with code
2. **Type Safety**: Request/response validation catches errors early
3. **Client Generation**: Generate client SDKs from the spec
4. **Testing**: Use the spec for contract testing
5. **Discoverability**: Interactive Swagger UI makes API exploration easy

## Next Steps

- Add more detailed descriptions to operations
- Add examples to schemas
- Implement request validation
- Add authentication/authorization schemas if needed
- Generate client libraries using the OpenAPI spec

## References

- [open_api_spex GitHub](https://github.com/open-api-spex/open_api_spex)
- [OpenAPI 3.0 Specification](https://swagger.io/specification/)
- [Swagger UI](https://swagger.io/tools/swagger-ui/)
