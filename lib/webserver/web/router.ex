defmodule Webserver.Web.Router do
  use Plug.Router

  plug(Plug.Parsers, parsers: [:json], json_decoder: Jason)

  # Add OpenAPI spec plug
  plug(OpenApiSpex.Plug.PutApiSpec, module: Webserver.Web.ApiSpec)

  plug(ScalarPlug, path: "/api/docs", spec_href: "/api/openapi", title: "API Documentation")

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
    |> OpenApiSpex.Plug.SwaggerUI.call(%{path: "/api/openapi"})
  end

  get "/" do
    Webserver.Web.Controllers.HealthController.index(conn)
  end

  get "/nodes" do
    Webserver.Web.Controllers.NodeController.index(conn)
  end

  post "/kv" do
    Webserver.Web.Controllers.KVController.put(conn)
  end

  get "/kv/:key" do
    Webserver.Web.Controllers.KVController.get(conn, key)
  end

  match _ do
    send_resp(conn, 404, "Not Found")
  end
end
