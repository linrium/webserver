defmodule Webserver.Web.Controllers.KVController do
  import Plug.Conn
  require Logger
  alias OpenApiSpex.{MediaType, Operation, RequestBody, Response}
  alias Webserver.Schemas

  def open_api_operation(:put) do
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
            schema: Webserver.Schemas.KVRequestBody
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

  def open_api_operation(:get) do
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

  def put(conn) do
    case Webserver.Schemas.KVRequest.changeset(conn.body_params) do
      %Ecto.Changeset{valid?: true} ->
        %{"key" => key, "value" => value} = conn.body_params
        Webserver.Services.KV.put(key, value)

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(%{status: "ok", node: Node.self()}))

      changeset ->
        errors =
          Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
            Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
              opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
            end)
          end)

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(400, Jason.encode!(%{errors: errors}))
    end
  end

  def get(conn, key) do
    # Query all nodes
    nodes = [Node.self() | Node.list()]

    # Simple scatter-gather to find the value
    result =
      Enum.find_value(nodes, fn node ->
        try do
          case :rpc.call(node, Webserver.Services.KV, :get, [key]) do
            nil -> nil
            value -> %{value: value, from_node: node}
          end
        catch
          _, _ -> nil
        end
      end)

    case result do
      nil ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(404, Jason.encode!(%{error: "not found"}))

      data ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, Jason.encode!(data))
    end
  end
end
