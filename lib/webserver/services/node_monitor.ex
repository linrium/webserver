defmodule Webserver.Services.NodeMonitor do
  use GenServer
  require Logger

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    # Subscribe to node connection events
    :net_kernel.monitor_nodes(true)
    Logger.info("🟢 NodeMonitor started on #{Node.self()}")
    Logger.info("🟢 Current cluster: #{inspect(Node.list())}")
    {:ok, %{}}
  end

  @impl true
  def handle_info({:nodeup, node}, state) do
    Logger.info("🟢 Node connected: #{node} | Current cluster: #{inspect(Node.list())}")
    {:noreply, state}
  end

  @impl true
  def handle_info({:nodedown, node}, state) do
    Logger.warning("🔴 Node disconnected: #{node} | Current cluster: #{inspect(Node.list())}")
    {:noreply, state}
  end
end
