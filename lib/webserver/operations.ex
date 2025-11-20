defmodule Webserver.Operations do
  @moduledoc """
  OpenAPI operation definitions for each endpoint.
  """
  alias OpenApiSpex.{MediaType, Operation, RequestBody, Response}
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
          200 => %Response{
            description: "Success",
            content: %{
              "text/plain" => %MediaType{
                example: "Hello World"
              }
            }
          }
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
          200 => %Response{
            description: "Nodes list",
            content: %{
              "application/json" => %MediaType{
                schema: Schemas.NodesResponse
              }
            }
          }
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
        requestBody: %RequestBody{
          description: "KV pair to store",
          required: true,
          content: %{
            "application/json" => %MediaType{
              schema: Webserver.Schemas.KVRequest
            }
          }
        },
        responses: %{
          200 => %Response{
            description: "Success",
            content: %{
              "application/json" => %MediaType{
                schema: Schemas.KVResponse
              }
            }
          },
          400 => %Response{
            description: "Validation error",
            content: %{
              "application/json" => %MediaType{
                schema: Schemas.ErrorResponse
              }
            }
          }
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
        description:
          "Retrieves a value from the distributed KV store by searching all cluster nodes",
        operationId: "GetKV.get",
        parameters: [
          Operation.parameter(:key, :path, :string, "The key to retrieve",
            required: true,
            example: "user:123"
          )
        ],
        responses: %{
          200 => %Response{
            description: "Value found",
            content: %{
              "application/json" => %MediaType{
                schema: Schemas.KVGetResponse
              }
            }
          },
          404 => %Response{
            description: "Key not found",
            content: %{
              "application/json" => %MediaType{
                schema: Schemas.ErrorResponse
              }
            }
          }
        }
      }
    end
  end
end
