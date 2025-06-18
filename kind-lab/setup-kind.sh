#!/bin/bash
set -e

# Script to set up a multi-node Kind cluster
# Usage: ./setup-kind.sh [CLUSTER_NAME]
# If CLUSTER_NAME is not provided, "kind-multi-node" will be used as default

# Detect OS
OS="$(uname -s)"
case "${OS}" in
    Linux*)     MACHINE=Linux;;
    Darwin*)    MACHINE=Mac;;
    *)          MACHINE="UNKNOWN:${OS}"
esac

echo "Detected OS: $MACHINE"

# Set cluster name (default or from command line argument)
CLUSTER_NAME=${1:-kind-multi-node}
echo "Setting up a multi-node Kind cluster with name: $CLUSTER_NAME"

# Function to install dependencies based on OS
install_dependencies() {
    # Check if Kind is installed
    if ! command -v kind &> /dev/null; then
        echo "Kind is not installed. Installing Kind..."
        
        if [ "$MACHINE" == "Mac" ]; then
            # Install Kind for macOS
            brew install kind
        elif [ "$MACHINE" == "Linux" ]; then
            # Install Kind for Linux
            echo "Installing Kind for Linux..."
            # Download the latest version of Kind
            curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.22.0/kind-linux-amd64
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

# Create Kind cluster configuration
echo "Creating Kind cluster configuration..."

cat > kind-config.yaml << EOF
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

# Delete any existing Kind cluster with the same name
echo "Deleting any existing Kind clusters with the name '$CLUSTER_NAME'..."
kind delete cluster --name ${CLUSTER_NAME} || true

# Create a new Kind cluster
echo "Creating a new Kind cluster with 3 nodes (1 control-plane, 2 workers) and name '$CLUSTER_NAME'..."
kind create cluster --config=kind-config.yaml

# Verify the cluster status
echo "Verifying cluster status..."
kubectl get nodes

# Install Metrics Server
echo "Installing Metrics Server..."
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Install Ingress Controller (NGINX)
echo "Installing NGINX Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Print cluster info
echo "Cluster Information:"
kubectl cluster-info

echo "Multi-node Kind cluster setup complete!"
echo "Cluster Name: $CLUSTER_NAME"
echo "To access the cluster with kubectl, run: kubectl get nodes"
echo "NGINX Ingress Controller is being deployed. It may take a minute to be ready."
echo "You can check its status with: kubectl get pods -n ingress-nginx"
echo "To delete this cluster when no longer needed, run: kind delete cluster --name $CLUSTER_NAME"
