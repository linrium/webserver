# Libcluster in Kubernetes: How Node Discovery and Monitoring Works

This document explains how `libcluster` enables automatic cluster formation in Kubernetes and how our `NodeMonitor` logs node connections.

## Overview

In a distributed Elixir system, nodes need to:
1. **Discover** each other (find other nodes in the cluster)
2. **Connect** to each other (establish distributed Erlang connections)
3. **Monitor** the cluster state (know when nodes join/leave)

`libcluster` handles discovery and connection (#1 and #2), while our `NodeMonitor` handles logging (#3).

## How Libcluster Works in Kubernetes

### The Challenge

When you deploy multiple pods in Kubernetes:
- Each pod gets a **dynamic IP address**
- Pods can be created/destroyed at any time
- Elixir nodes need to know about each other to form a cluster

### The Solution: Kubernetes Strategy

Libcluster's `Cluster.Strategy.Kubernetes` uses the **Kubernetes API** to discover pods:

```elixir
config :libcluster,
  topologies: [
    k8s: [
      strategy: Cluster.Strategy.Kubernetes,
      config: [
        mode: :ip,
        kubernetes_node_basename: "webserver",
        kubernetes_selector: "app=webserver",
        polling_interval: 3_000
      ]
    ]
  ]
```

### How It Works Step-by-Step

#### 1. **Pod Discovery via Kubernetes API**

Every 3 seconds (polling_interval), libcluster:
1. Queries the Kubernetes API: "Give me all pods with label `app=webserver`"
2. Kubernetes returns a list of pod IPs that match the selector
3. Libcluster converts these IPs to Elixir node names

```
Kubernetes API Response:
- Pod 1: 10.1.2.3
- Pod 2: 10.1.2.4
- Pod 3: 10.1.2.5

Converted to Node Names:
- webserver@10.1.2.3
- webserver@10.1.2.4
- webserver@10.1.2.5
```

#### 2. **Automatic Connection**

For each discovered node:
- If **not already connected**: libcluster calls `Node.connect(node_name)`
- If **already connected**: does nothing
- If **no longer in the list**: the connection naturally drops

#### 3. **Distributed Erlang Takes Over**

Once `Node.connect/1` succeeds:
- Erlang's **distribution protocol** establishes a persistent TCP connection
- Nodes can now send messages to each other
- The connection is **bidirectional** and **fully meshed**

```
┌─────────────┐         ┌─────────────┐
│   Node A    │◄───────►│   Node B    │
│ 10.1.2.3    │         │ 10.1.2.4    │
└─────────────┘         └─────────────┘
       ▲                       ▲
       │                       │
       └───────────┬───────────┘
                   │
            ┌─────────────┐
            │   Node C    │
            │ 10.1.2.5    │
            └─────────────┘
```

## How Node Monitoring Works

### The `:net_kernel` Module

Erlang's `:net_kernel` is the **core distribution manager**. It:
- Manages all node connections
- Sends notifications when nodes connect/disconnect
- Provides the `monitor_nodes/1` function

### Our NodeMonitor Implementation

```elixir
defmodule Webserver.NodeMonitor do
  use GenServer
  require Logger

  def init(_) do
    # Subscribe to node events
    :net_kernel.monitor_nodes(true)
    {:ok, %{}}
  end

  def handle_info({:nodeup, node}, state) do
    Logger.info("🟢 Node connected: #{node}")
    {:noreply, state}
  end

  def handle_info({:nodedown, node}, state) do
    Logger.warning("🔴 Node disconnected: #{node}")
    {:noreply, state}
  end
end
```

### When Events Are Triggered

#### `:nodeup` Event

Sent to **all currently connected nodes** when:
- A new node successfully connects via `Node.connect/1`
- Libcluster discovers a new pod and connects to it

**Example Flow:**
```
Time T0: Cluster has Node A and Node B
Time T1: Node C starts and libcluster on A and B discover it
Time T2: Node A calls Node.connect(:"webserver@10.1.2.5")
Time T3: Connection succeeds
Time T4: :net_kernel sends {:nodeup, :"webserver@10.1.2.5"} to Node A
Time T5: Node B also connects and receives {:nodeup, :"webserver@10.1.2.5"}
```

#### `:nodedown` Event

Sent to **all remaining nodes** when:
- A node crashes or is terminated
- Network partition occurs
- Pod is deleted by Kubernetes

**Example Flow:**
```
Time T0: Cluster has Node A, B, and C
Time T1: kubectl delete pod webserver-xyz (Node C)
Time T2: TCP connection to Node C breaks
Time T3: :net_kernel detects connection loss
Time T4: :net_kernel sends {:nodedown, :"webserver@10.1.2.5"} to Node A and B
Time T5: NodeMonitor logs "🔴 Node disconnected: webserver@10.1.2.5"
```

## Complete Flow: Scaling Up in Kubernetes

Let's trace what happens when you run `kubectl scale deployment/webserver --replicas=3`:

### Initial State
- 1 pod running: `webserver-abc` (Node A at 10.1.2.3)

### Step 1: Kubernetes Creates New Pods
```bash
kubectl scale deployment/webserver --replicas=3
```
- Kubernetes creates `webserver-def` (10.1.2.4) and `webserver-ghi` (10.1.2.5)
- Both new pods start their Elixir applications

### Step 2: Libcluster Discovery (on Node A)
```
[Node A - 10.1.2.3]
- Libcluster polls Kubernetes API
- API returns: [10.1.2.3, 10.1.2.4, 10.1.2.5]
- Libcluster sees two new IPs
- Calls: Node.connect(:"webserver@10.1.2.4")
- Calls: Node.connect(:"webserver@10.1.2.5")
```

### Step 3: Connection Established
```
[Node A]
- Connection to 10.1.2.4 succeeds
- :net_kernel sends {:nodeup, :"webserver@10.1.2.4"} to Node A's processes
- NodeMonitor receives the message
- Logs: "🟢 Node connected: webserver@10.1.2.4 | Current cluster: [...]"
```

### Step 4: Reverse Discovery (on Node B and C)
```
[Node B - 10.1.2.4]
- Libcluster polls Kubernetes API
- Discovers Node A and Node C
- Connects to both
- Receives {:nodeup, ...} events
- NodeMonitor logs connections

[Node C - 10.1.2.5]
- Same process as Node B
```

### Final State
```
All nodes are fully connected:
- Node A knows about B and C
- Node B knows about A and C
- Node C knows about A and B

Each node logged:
🟢 Node connected: webserver@10.1.2.4
🟢 Node connected: webserver@10.1.2.5
```

## Why This Design Works

### 1. **Separation of Concerns**
- **Libcluster**: Handles discovery and connection
- **:net_kernel**: Manages low-level distribution
- **NodeMonitor**: Provides observability

### 2. **Resilience**
- If libcluster crashes, existing connections remain
- If a node crashes, :net_kernel automatically detects it
- Kubernetes will restart crashed pods, and libcluster will reconnect

### 3. **Kubernetes-Native**
- Uses Kubernetes labels for pod selection
- Works with any Kubernetes cluster (no special networking required)
- Automatically adapts to scaling events

### 4. **Real-Time Monitoring**
- Events are sent **immediately** when connections change
- No polling required for monitoring
- All nodes have consistent view of cluster state

## Configuration Details

### Required Kubernetes Permissions

For libcluster to query the Kubernetes API, your pods need RBAC permissions:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: webserver
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: webserver-pod-reader
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: webserver-pod-reader-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: webserver-pod-reader
subjects:
- kind: ServiceAccount
  name: webserver
```

### Configuration Options Explained

```elixir
config: [
  # Use pod IPs instead of DNS names
  mode: :ip,
  
  # Base name for Elixir nodes (becomes "webserver@IP")
  kubernetes_node_basename: "webserver",
  
  # Kubernetes label selector to find pods
  kubernetes_selector: "app=webserver",
  
  # How often to poll Kubernetes API (milliseconds)
  polling_interval: 3_000
]
```

## Debugging Tips

### Check if Nodes Are Connected
```elixir
# In IEx on any pod
Node.list()
# => [:"webserver@10.1.2.4", :"webserver@10.1.2.5"]
```

### Check Current Node Name
```elixir
Node.self()
# => :"webserver@10.1.2.3"
```

### View Logs
```bash
# See NodeMonitor logs
kubectl logs -f deployment/webserver | grep "Node connected"
```

### Test Connection Manually
```elixir
# In IEx
Node.connect(:"webserver@10.1.2.4")
# => true (success) or false (failure)
```

## Common Issues

### Issue: Nodes Not Connecting

**Symptoms:** `Node.list()` returns `[]`

**Possible Causes:**
1. **RBAC permissions missing** - libcluster can't query Kubernetes API
2. **Wrong label selector** - pods don't match `kubernetes_selector`
3. **Firewall rules** - Erlang distribution port (default 4369) blocked
4. **Cookie mismatch** - nodes have different Erlang cookies

**Solution:**
```bash
# Check if libcluster can see pods
kubectl logs deployment/webserver | grep -i cluster

# Verify pod labels
kubectl get pods --show-labels

# Check RBAC
kubectl auth can-i list pods --as=system:serviceaccount:default:webserver
```

### Issue: Nodes Connect Then Disconnect

**Symptoms:** Frequent `:nodeup` and `:nodedown` events

**Possible Causes:**
1. **Network instability** - pods can't maintain TCP connections
2. **Resource constraints** - pods being OOM killed
3. **Cookie mismatch** - authentication fails after initial connection

**Solution:**
```bash
# Check pod health
kubectl get pods
kubectl describe pod <pod-name>

# Check resource usage
kubectl top pods
```

## Summary

The complete flow is:

1. **Libcluster** discovers pods via Kubernetes API
2. **Libcluster** calls `Node.connect/1` for each discovered pod
3. **Erlang distribution** establishes TCP connections
4. **:net_kernel** sends `:nodeup` events to all connected nodes
5. **NodeMonitor** receives events and logs them
6. When pods are deleted, **:net_kernel** sends `:nodedown` events
7. **NodeMonitor** logs disconnections

This architecture provides automatic cluster formation with full observability in Kubernetes environments.

## Why `rel/env.sh.eex` is Required in Kubernetes

### The Problem: Dynamic Node Names

For distributed Erlang to work, each node must have a **unique name**. In Kubernetes:
- Pod IPs are **assigned dynamically** at runtime
- You don't know the IP address until the pod starts
- Each pod needs a different node name (e.g., `webserver@10.1.2.3`, `webserver@10.1.2.4`)

**Without `rel/env.sh.eex`**, your Elixir release would use a **static node name** configured at build time, causing all pods to have the **same node name**, which breaks distributed Erlang.

### The Solution: Runtime Configuration

The `rel/env.sh.eex` file is a **template** that gets evaluated when the release is built. It allows you to configure environment variables that will be evaluated **at runtime** (when the container starts), not at build time.

#### File: `rel/env.sh.eex`

```bash
#!/bin/sh
export RELEASE_DISTRIBUTION=name
export RELEASE_NODE=<%= @release.name %>@${POD_IP}
```

Let's break this down:

#### 1. **`RELEASE_DISTRIBUTION=name`**

This tells the Erlang VM to use **long names** for distribution.

Erlang supports two types of node names:
- **Short names** (`-sname`): `node@hostname` (no domain, local network only)
- **Long names** (`-name`): `node@fully.qualified.domain` or `node@ip.address`

In Kubernetes, we use **long names with IP addresses** because:
- Pods don't have stable hostnames
- DNS resolution can be slow or unreliable
- IP addresses are guaranteed to be unique

#### 2. **`RELEASE_NODE=<%= @release.name %>@${POD_IP}`**

This sets the node name dynamically:

- **`<%= @release.name %>`**: Template variable evaluated **at build time**
  - Replaced with your release name (from `mix.exs`)
  - In your case: `webserver`
  
- **`${POD_IP}`**: Environment variable evaluated **at runtime**
  - Injected by Kubernetes when the pod starts
  - Different for each pod

**Result:** Each pod gets a unique node name like `webserver@10.1.2.3`

### How POD_IP Gets Injected

In your Kubernetes deployment, you use the **Downward API** to expose the pod's IP as an environment variable:

#### File: `k8s/deployment.yaml`

```yaml
spec:
  containers:
  - name: webserver
    env:
    - name: POD_IP
      valueFrom:
        fieldRef:
          fieldPath: status.podIP  # Kubernetes injects the pod's IP here
```

**Flow:**
1. Kubernetes starts a pod and assigns it IP `10.1.2.3`
2. Kubernetes sets `POD_IP=10.1.2.3` in the container's environment
3. When the Elixir release starts, it sources `env.sh` (generated from `env.sh.eex`)
4. The shell expands `${POD_IP}` to `10.1.2.3`
5. `RELEASE_NODE` becomes `webserver@10.1.2.3`
6. The Erlang VM starts with this node name

### What Happens Without `rel/env.sh.eex`

If you don't configure the node name dynamically, Elixir uses a **default node name** or one configured at build time:

```
# All pods would have the same name:
webserver@127.0.0.1  # or
webserver@localhost  # or
nonode@nohost        # (not distributed at all)
```

**Problems:**
1. **Nodes can't connect to themselves**: If all pods think they're `webserver@localhost`, they can't distinguish between each other
2. **Distributed Erlang fails**: You can't have two nodes with the same name in a cluster
3. **Libcluster can't work**: It tries to connect to `webserver@10.1.2.4`, but that node thinks its name is `webserver@localhost`

### The Complete Build and Runtime Flow

#### Build Time (Docker Build)

```dockerfile
# Dockerfile
COPY rel rel
RUN mix release
```

When `mix release` runs:
1. Reads `rel/env.sh.eex` template
2. Evaluates `<%= @release.name %>` → `webserver`
3. Generates `_build/prod/rel/webserver/releases/0.1.0/env.sh`:
   ```bash
   #!/bin/sh
   export RELEASE_DISTRIBUTION=name
   export RELEASE_NODE=webserver@${POD_IP}
   ```
4. Note: `${POD_IP}` is **NOT** expanded yet (it's a shell variable, not an Elixir template variable)

#### Runtime (Container Start)

```bash
# When the container starts
/app/bin/webserver start
```

The release boot script:
1. Sources `env.sh`
2. Shell expands `${POD_IP}` using the environment variable from Kubernetes
3. Sets `RELEASE_NODE=webserver@10.1.2.3`
4. Starts the Erlang VM with: `erl -name webserver@10.1.2.3 -setcookie secret_cookie ...`

### Alternative Approaches (and Why We Don't Use Them)

#### 1. **Hardcoded Node Name**
```elixir
# config/runtime.exs
config :kernel,
  distributed: [{:webserver, [:"webserver@10.1.2.3"]}]
```
❌ **Doesn't work**: IP is different for each pod

#### 2. **DNS-Based Names**
```bash
export RELEASE_NODE=webserver@${HOSTNAME}.default.svc.cluster.local
```
❌ **Slow and unreliable**: DNS lookups add latency, can fail

#### 3. **Using Hostname Instead of IP**
```bash
export RELEASE_NODE=webserver@${HOSTNAME}
```
❌ **Doesn't work with libcluster's `:ip` mode**: Libcluster discovers IPs, not hostnames

### Why This File Must Be in the Dockerfile

The `rel/` directory must be copied **before** running `mix release`:

```dockerfile
# Dockerfile
COPY rel rel          # ← Must come before mix release
RUN mix release       # ← This reads rel/env.sh.eex
```

If you don't include `COPY rel rel`, the release will be built **without** the custom environment configuration, and you'll get the default behavior (which doesn't work in Kubernetes).

### Verification

You can verify the node name is set correctly:

```bash
# SSH into a running pod
kubectl exec -it deployment/webserver -- /app/bin/webserver remote

# In the IEx shell
iex> Node.self()
:"webserver@10.1.2.3"  # ✅ Unique IP-based name

# Check what other nodes are connected
iex> Node.list()
[:"webserver@10.1.2.4", :"webserver@10.1.2.5"]  # ✅ Other pods with different IPs
```

### Summary: Why `rel/env.sh.eex` is Essential

| Component | Purpose | When Evaluated |
|-----------|---------|----------------|
| `rel/env.sh.eex` | Template for runtime environment configuration | Build time (by `mix release`) |
| `<%= @release.name %>` | Release name from `mix.exs` | Build time |
| `${POD_IP}` | Shell variable for pod IP | Runtime (by shell) |
| `RELEASE_NODE` | Tells Erlang VM what node name to use | Runtime (before VM starts) |
| `RELEASE_DISTRIBUTION` | Tells Erlang VM to use long names | Runtime (before VM starts) |

**Without this file:**
- All pods would have the same node name
- Distributed Erlang would fail
- Libcluster couldn't form a cluster
- Your application would run in isolated mode on each pod

**With this file:**
- Each pod gets a unique node name based on its IP
- Distributed Erlang works correctly
- Libcluster can discover and connect nodes
- Your cluster forms automatically in Kubernetes ✅
