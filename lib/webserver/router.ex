defmodule Webserver.Router do
  use Plug.Router

  plug(Plug.Parsers, parsers: [:json], json_decoder: Jason)

  # Add OpenAPI spec plug
  plug(OpenApiSpex.Plug.PutApiSpec, module: Webserver.ApiSpec)

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
    send_resp(conn, 200, "Hello World")
  end

  get "/nodes" do
    nodes = [Node.self() | Node.list()]

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(%{nodes: nodes}))
  end

  post "/kv" do
    case Webserver.Requests.KVRequest.changeset(conn.body_params) do
      %Ecto.Changeset{valid?: true} ->
        %{"key" => key, "value" => value} = conn.body_params
        Webserver.KV.put(key, value)

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

  get "/kv/:key" do
    # Query all nodes
    nodes = [Node.self() | Node.list()]

    # Simple scatter-gather to find the value
    result =
      Enum.find_value(nodes, fn node ->
        try do
          case :rpc.call(node, Webserver.KV, :get, [key]) do
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

  match _ do
    send_resp(conn, 404, "Not Found")
  end
end
