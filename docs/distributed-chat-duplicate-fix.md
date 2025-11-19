# Distributed Chat Room - Duplicate Message Issue

## The Problem

When implementing the distributed chat room with multiple Kubernetes pods (replicas), users were receiving duplicate messages. For example, when Bob sent "hi", Alice would receive:

```
< {"timestamp":"2025-11-19 12:41:14.139022Z","user":"Bob","text":"hi"}
< {"timestamp":"2025-11-19 12:41:14.139022Z","user":"Bob","text":"hi"}
```

## Root Cause

The issue occurred because of how the message broadcasting was architected in a **multi-node cluster**:

### Original (Broken) Architecture

```
User Bob sends "hi"
    ↓
Bob's WebSocket Handler (on Pod 1)
    ↓
ChatServer.broadcast() sends to ALL ChatServer instances
    ↓
┌───────────────────────────────────────────────┐
│  ChatServer on Pod 1  │  ChatServer on Pod 2  │
│         ↓             │         ↓             │
│  Broadcasts to        │  Broadcasts to        │
│  local clients        │  local clients        │
└───────────────────────────────────────────────┘
    ↓                           ↓
Alice (connected to Pod 1) receives message from BOTH ChatServers
```

**Why duplicates?**
1. Bob's message was sent to **all ChatServer instances** (Pod 1 and Pod 2)
2. **Each ChatServer** then broadcast the message to its local clients
3. Alice, connected to Pod 1, received the message from:
   - ChatServer on Pod 1 ✓
   - ChatServer on Pod 2 ✓ (duplicate!)

The `:pg` (Process Groups) library works **across the entire cluster**, so when we called `:pg.get_members(:chat_clients)`, it returned clients from **all pods**, not just the local pod.

## The Solution

Instead of having each ChatServer broadcast to its local clients, we broadcast **directly to all clients in the cluster** from the originating ChatServer:

### Fixed Architecture

```
User Bob sends "hi"
    ↓
Bob's WebSocket Handler (on Pod 1)
    ↓
ChatServer.broadcast() on Pod 1
    ↓
┌──────────────────────────────────────────────────┐
│  Direct broadcast to ALL clients in cluster      │
│  (using :pg.get_members(:chat_clients))          │
│                                                  │
│  - Alice on Pod 1 ✓                              │
│  - Charlie on Pod 2 ✓                            │
│  - Excludes Bob (sender) ✗                       │
└──────────────────────────────────────────────────┘
    ↓
Separate message to update history on all ChatServers
```

## Code Changes

### Before (Broken)

```elixir
def broadcast(user, text, sender_pid) do
  message = %{...}
  
  # Send to all ChatServers
  :pg.get_members(:chat_servers)
  |> Enum.each(fn pid -> send(pid, {:new_message, message, sender_pid}) end)
end

def handle_info({:new_message, message, sender_pid}, history) do
  # Each ChatServer broadcasts to its local clients
  :pg.get_members(:chat_clients)
  |> Enum.reject(fn pid -> pid == sender_pid end)
  |> Enum.each(fn pid -> send(pid, {:chat_message, message}) end)
  
  # Update history
  new_history = [message | history] |> Enum.take(@history_limit)
  {:noreply, new_history}
end
```

### After (Fixed)

```elixir
def broadcast(user, text, sender_pid) do
  message = %{...}
  
  # Broadcast DIRECTLY to all clients in the cluster (except sender)
  :pg.get_members(:chat_clients)
  |> Enum.reject(fn pid -> pid == sender_pid end)
  |> Enum.each(fn pid -> send(pid, {:chat_message, message}) end)
  
  # Separately update history on all ChatServers
  :pg.get_members(:chat_servers)
  |> Enum.each(fn pid -> send(pid, {:update_history, message}) end)
end

def handle_info({:update_history, message}, history) do
  # Just update history, don't broadcast (already done above)
  new_history = [message | history] |> Enum.take(@history_limit)
  {:noreply, new_history}
end
```

## Key Insights

1. **`:pg` is cluster-wide**: When you call `:pg.get_members(:chat_clients)`, it returns **all** clients across **all pods** in the Kubernetes cluster, not just local ones.

2. **Separation of concerns**: 
   - **Broadcasting to clients** = done once, directly from the originating ChatServer
   - **Updating history** = done on all ChatServers to keep history in sync

3. **Sender exclusion**: The sender's PID is passed through so they don't receive their own message back from the server (the client-side JavaScript handles displaying their own messages).

## Testing

With 2 replicas in Kubernetes:
- Bob connects to Pod 1
- Alice connects to Pod 1 or Pod 2 (doesn't matter)
- Bob sends "hi"
- Alice receives exactly **1 message** ✓
- Bob doesn't receive his own message from the server ✓
- Message appears in history on both pods ✓
