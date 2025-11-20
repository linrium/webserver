defmodule Webserver.Web.SocketHandler do
  @behaviour :cowboy_websocket

  def init(req, _state) do
    # Parse username from query params
    username =
      case :cowboy_req.parse_qs(req) do
        qs ->
          Enum.find_value(qs, "Guest", fn
            {"username", name} -> name
            _ -> nil
          end)
      end

    {:cowboy_websocket, req, %{username: username}}
  end

  def websocket_init(state) do
    # Join the chat clients group to receive broadcasts
    :pg.join(:chat_clients, self())

    # Send history to the new user
    history = Webserver.Services.ChatServer.get_history()

    Enum.each(history, fn msg ->
      json = Jason.encode!(msg)
      send(self(), {:text, json})
    end)

    {:ok, state}
  end

  def websocket_handle({:text, message}, state) do
    # Broadcast the message via ChatServer, passing our PID
    Webserver.Services.ChatServer.broadcast(state.username, message, self())
    {:ok, state}
  end

  def websocket_info({:chat_message, message}, state) do
    # Forward broadcasted messages to the client
    json = Jason.encode!(message)
    {:reply, {:text, json}, state}
  end

  def websocket_info({:text, json}, state) do
    # Handle self-sent messages (like history)
    {:reply, {:text, json}, state}
  end

  def websocket_info(_info, state) do
    {:ok, state}
  end
end
