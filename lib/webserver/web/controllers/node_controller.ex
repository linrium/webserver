defmodule Webserver.Web.Controllers.NodeController do
  import Plug.Conn
  alias OpenApiSpex.{MediaType, Operation, Response}
  alias Webserver.Schemas

  def open_api_operation(:index) do
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

  def index(conn) do
    nodes = [Node.self() | Node.list()]

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(%{nodes: nodes}))
  end
end
