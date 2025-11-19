defmodule Webserver.ChatServer do
  use GenServer

  @history_limit 50

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def broadcast(user, text, sender_pid) do
    message = %{
      user: user,
      text: text,
      timestamp: DateTime.utc_now() |> DateTime.to_string()
    }

    # Broadcast directly to all clients in the cluster (except sender)
    :pg.get_members(:chat_clients)
    |> Enum.reject(fn pid -> pid == sender_pid end)
    |> Enum.each(fn pid -> send(pid, {:chat_message, message}) end)

    # Also update history on all chat servers
    :pg.get_members(:chat_servers)
    |> Enum.each(fn pid -> send(pid, {:update_history, message}) end)
  end

  def get_history do
    GenServer.call(__MODULE__, :get_history)
  end

  # Server Callbacks

  @impl true
  def init(_) do
    :pg.join(:chat_servers, self())
    {:ok, []}
  end

  @impl true
  def handle_call(:get_history, _from, history) do
    {:reply, Enum.reverse(history), history}
  end

  @impl true
  def handle_info({:update_history, message}, history) do
    # Just update history, don't broadcast (already done in broadcast/3)
    new_history = [message | history] |> Enum.take(@history_limit)
    {:noreply, new_history}
  end
end
