#!/bin/bash
set -euo pipefail

# 🔶 🚀 Multi-Node Kind Lab Setup Script 🚀 🔶
#
# Script to set up a multi-node Kind cluster
# Usage: ./setup-kind.sh [CLUSTER_NAME]
# If CLUSTER_NAME is not provided, "kind-multi-node" will be used as default

# 🔍 Detect OS
OS="$(uname -s)"
case "${OS}" in
    Linux*)     MACHINE=Linux;;   # 🐧 Linux
    Darwin*)    MACHINE=Mac;;     # 🍎 macOS
    *)          MACHINE="UNKNOWN:${OS}"
esac

echo "🖥️  Detected OS: $MACHINE"

# 🏷️ Set cluster name (default or from command line argument)
CLUSTER_NAME=${1:-kind-multi-node}
echo "🚀 Setting up a multi-node Kind cluster with name: $CLUSTER_NAME"

# 📦 Function to install dependencies based on OS
install_dependencies() {
    # Check if Kind is installed
    if ! command -v kind &> /dev/null; then
        echo "Kind is not installed. Installing Kind..."
        
        if [ "$MACHINE" == "Mac" ]; then
            # Install Kind for macOS
            brew install kind
        elif [ "$MACHINE" == "Linux" ]; then
            # Install Kind for Linux (auto-detect latest version and architecture)
            echo "Installing Kind for Linux..."
            KIND_VERSION=$(curl -s https://api.github.com/repos/kubernetes-sigs/kind/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' || echo "v0.22.0")
            ARCH=$(uname -m)
            case "$ARCH" in
                x86_64)  KIND_ARCH="amd64" ;;
                aarch64) KIND_ARCH="arm64" ;;
                *)       echo "Unsupported architecture: $ARCH"; exit 1 ;;
            esac
            echo "Detected Kind version: $KIND_VERSION, architecture: $KIND_ARCH"
            curl -fLo ./kind "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-${KIND_ARCH}"
            # Make it executable and move it to a directory in your PATH
            chmod +x ./kind
            sudo mv ./kind /usr/local/bin/
        else
            echo "Unsupported OS. Please install Kind manually and run this script again."
            exit 1
        fi
        
        if [ $? -ne 0 ]; then
            echo "Failed to install Kind. Please install it manually and run this script again."
            exit 1
        fi
    else
        echo "Kind is already installed."
    fi

    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        echo "kubectl is not installed. Installing kubectl..."
        
        if [ "$MACHINE" == "Mac" ]; then
            # Install kubectl for macOS
            brew install kubectl
        elif [ "$MACHINE" == "Linux" ]; then
            # Install kubectl for Linux
            echo "Installing kubectl for Linux..."
            curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
            sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
            rm kubectl
        else
            echo "Unsupported OS. Please install kubectl manually and run this script again."
            exit 1
        fi
        
        if [ $? -ne 0 ]; then
            echo "Failed to install kubectl. Please install it manually and run this script again."
            exit 1
        fi
    else
        echo "kubectl is already installed."
    fi

    # Check if Docker is installed and running
    if ! command -v docker &> /dev/null; then
        echo "Docker is not installed. Please install Docker and run this script again."
        exit 1
    fi

    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        echo "Docker daemon is not running. Please start Docker and run this script again."
        exit 1
    fi
}

# Install dependencies
install_dependencies

# 📊 Function to offer optional Prometheus + Grafana monitoring deployment
offer_monitoring() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 Monitoring Stack (Prometheus + Grafana)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    read -r -p "Would you like to deploy Prometheus & Grafana to monitor the cluster? [y/N]: " DEPLOY_MONITORING
    if [[ "${DEPLOY_MONITORING:-}" =~ ^[Yy]$ ]]; then
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        MONITORING_SCRIPT="$SCRIPT_DIR/../demo-app/monitoring-demo/deploy-monitoring.sh"
        if [ -f "$MONITORING_SCRIPT" ]; then
            echo "📊 Deploying monitoring stack..."
            bash "$MONITORING_SCRIPT" kind "$CLUSTER_NAME"
        else
            echo "⚠️  Monitoring script not found at: $MONITORING_SCRIPT"
            echo "💡 To deploy manually, run from the repo root:"
            echo "   ./demo-app/monitoring-demo/deploy-monitoring.sh kind $CLUSTER_NAME"
        fi
    else
        echo "⏭️  Skipping monitoring stack deployment."
        echo "💡 To deploy later, run from the repo root:"
        echo "   ./demo-app/monitoring-demo/deploy-monitoring.sh kind $CLUSTER_NAME"
    fi
}

# 🔍 Check if a cluster with this name already exists
echo "🔍 Checking if a Kind cluster named '$CLUSTER_NAME' already exists..."
if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
    echo "✅ Found existing cluster named '$CLUSTER_NAME'!"
    
    # Check if the control-plane container is running
    CONTAINER_RUNNING=$(docker ps -q --filter "name=${CLUSTER_NAME}-control-plane" --filter "status=running" | wc -l | tr -d ' ')
    
    if [ "$CONTAINER_RUNNING" -gt 0 ]; then
        echo "✅ Cluster is already running! No action needed."
        # Switch to this cluster's context
        kubectl config use-context "kind-${CLUSTER_NAME}"
        offer_monitoring
        exit 0
    else
        CONTAINER_EXISTS=$(docker ps -a -q --filter "name=${CLUSTER_NAME}-control-plane" | wc -l | tr -d ' ')
        if [ "$CONTAINER_EXISTS" -gt 0 ]; then
            echo "🔄 Existing containers found. Attempting to start them..."
            CONTAINER_IDS=$(docker ps -a --filter "name=${CLUSTER_NAME}-" --format "{{.ID}}")
            if [ -n "$CONTAINER_IDS" ]; then
                echo "$CONTAINER_IDS" | xargs docker start
            fi
            echo "✅ Containers started successfully!"
            # Switch to this cluster's context
            kubectl config use-context "kind-${CLUSTER_NAME}" 
            offer_monitoring
            exit 0
        else
            echo "⚠️ Cluster exists but no containers found. Creating new cluster..."
        fi
    fi
else
    echo "🆕 No existing cluster found. Creating a new cluster..."
fi

# 📝 Create Kind cluster configuration
echo "📝 Creating Kind cluster configuration..."

# Check for port conflicts before cluster creation
for port in 80 443; do
    if lsof -i ":${port}" &>/dev/null 2>&1 || ss -tlnp 2>/dev/null | grep -q ":${port} " 2>/dev/null; then
        echo "⚠️  Warning: Port ${port} is already in use. Kind cluster creation may fail."
        echo "   Please free up port ${port} or modify the port mappings."
    fi
done

# Use a temp file for the Kind config to avoid leaving stale files
KIND_CONFIG=$(mktemp "${TMPDIR:-/tmp}/kind-config.XXXXXX.yaml")
trap 'rm -f "$KIND_CONFIG"' EXIT

cat > "$KIND_CONFIG" << EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: ${CLUSTER_NAME}
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
- role: worker
- role: worker
EOF

# 🚀 Create a new Kind cluster
echo "🚀 Creating a new Kind cluster with 3 nodes (1 control-plane, 2 workers) and name '$CLUSTER_NAME'..."
if ! kind create cluster --config="$KIND_CONFIG"; then
    echo "❌ Failed to create Kind cluster. Please check the error above."
    exit 1
fi

# ✅ Verify the cluster status
echo "✅ Verifying cluster status..."
kubectl get nodes

# 📈 Install Metrics Server
echo "📈 Installing Metrics Server..."
if ! kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml; then
    echo "⚠️  Warning: Failed to install Metrics Server. You can install it manually later."
fi

# 🌐 Install Ingress Controller (NGINX)
echo "🌐 Installing NGINX Ingress Controller..."
if ! kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml; then
    echo "⚠️  Warning: Failed to install NGINX Ingress Controller. You can install it manually later."
fi

# ℹ️ Print cluster info
echo "ℹ️ Cluster Information:"
kubectl cluster-info

echo "🎉 Multi-node Kind cluster setup complete! 🎉"
echo "🏷️  Cluster Name: $CLUSTER_NAME"
echo "🔍 To access the cluster with kubectl, run: kubectl get nodes"
echo "⏱️  NGINX Ingress Controller is being deployed. It may take a minute to be ready."
echo "📊 You can check its status with: kubectl get pods -n ingress-nginx"
echo "🗑️  To delete this cluster when no longer needed, run: kind delete cluster --name $CLUSTER_NAME"

offer_monitoring
