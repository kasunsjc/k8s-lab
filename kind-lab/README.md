# 🔶 Multi-Node Kind Lab Setup

This lab provides a lightning-fast, lightweight multi-node Kubernetes development environment using Kind (Kubernetes IN Docker). The smart setup script is compatible with both macOS and Linux operating systems, enabling you to spin up a complete Kubernetes cluster in seconds.

## ✨ Key Features

- 🔱 A specialized 3-node Kubernetes cluster (1 control-plane, 2 workers) running on Docker
- 🧠 Smart cluster management that preserves and restarts existing clusters
- 📈 Metrics Server for resource utilization monitoring
- 🌐 NGINX Ingress Controller with ports 80 and 443 pre-configured and exposed to the host
- ⚡ Ultra-fast startup and teardown for rapid development cycles

## 📋 Prerequisites

### 🍎 For macOS

- macOS operating system
- [Homebrew](https://brew.sh/) package manager
- Docker Desktop installed and running

### 🐧 For Linux

- Linux operating system (Ubuntu, Debian, CentOS, etc.)
- Docker installed and running
- `sudo` privileges (for installing dependencies)
- `curl` installed

## 🚀 Setup Instructions

1. Make the setup script executable:

   ```bash
   chmod +x setup-kind.sh
   ```

2. Run the setup script:

   ```bash
   # Create a cluster with default name (kind-multi-node)
   ./setup-kind.sh
   
   # OR create a cluster with a custom name
   ./setup-kind.sh my-custom-cluster
   ```

   ✨ You can create multiple clusters with different names by specifying different cluster names, perfect for testing scenarios requiring multiple isolated environments.

## 🧠 Smart Cluster Management

The setup script implements smart cluster management capabilities, particularly useful with Kind:

- 🔍 **Cluster Detection**: The script checks if a cluster with the specified name already exists
- 🐳 **Container State Awareness**: If the cluster exists, the script checks if its containers are running
- 🔌 **Container Restart**: If the cluster containers are stopped, they will be restarted without recreating the cluster
- ⚡ **Efficiency**: No need to wait for cluster recreation when you've just temporarily stopped the containers
- 🛡️ **State Preservation**: Your workloads, configurations, and deployed applications remain intact

```bash
# If you run this command for an existing cluster with stopped containers
./setup-kind.sh my-cluster

# The script will detect the cluster and just restart the containers
# This is much faster than recreating the entire cluster
```

> 💡 **Tip for Kind Users**: Since Kind doesn't have a built-in "stop" command like Minikube, you can stop the containers manually using Docker commands, and the setup script will intelligently restart them:
> 
> ```bash
> # To stop Kind containers manually:
> docker stop my-cluster-control-plane my-cluster-worker my-cluster-worker2
> ```
