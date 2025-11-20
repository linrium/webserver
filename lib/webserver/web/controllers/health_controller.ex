defmodule Webserver.Web.Controllers.HealthController do
  import Plug.Conn
  alias OpenApiSpex.{MediaType, Operation, Response}

  def open_api_operation(:index) do
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

  def index(conn) do
    send_resp(conn, 200, "Hello World")
  end
end
