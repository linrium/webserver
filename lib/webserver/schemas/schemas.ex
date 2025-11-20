defmodule Webserver.Schemas do
  @moduledoc """
  OpenAPI schemas for request/response bodies.
  """
  alias OpenApiSpex.Schema

  defmodule KVRequestBody do
    @moduledoc false
    require OpenApiSpex

    OpenApiSpex.schema(%{
      title: "KVRequestBody",
      description: "Request body for storing a key-value pair",
      type: :object,
      properties: %{
        key: %Schema{type: :string, description: "The key to store", example: "user:123"},
        value: %Schema{
          type: :string,
          description: "The value to store",
          example: "John Doe"
        }
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
        node: %Schema{
          type: :string,
          description: "Node that handled the request",
          example: "webserver@127.0.0.1"
        }
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
        from_node: %Schema{
          type: :string,
          description: "Node where value was found",
          example: "webserver@127.0.0.1"
        }
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
