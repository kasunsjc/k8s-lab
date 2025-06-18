#!/bin/bash
set -e

# 🔷 🚀 Multi-Node Minikube Lab Setup Script 🚀 🔷
#
# Script to set up a multi-node Minikube cluster
# Usage: ./setup-minikube.sh [PROFILE_NAME]
# If PROFILE_NAME is not provided, "minikube-multinode" will be used as default

# 🔍 Detect OS
OS="$(uname -s)"
case "${OS}" in
    Linux*)     MACHINE=Linux;;   # 🐧 Linux
    Darwin*)    MACHINE=Mac;;     # 🍎 macOS
    *)          MACHINE="UNKNOWN:${OS}"
esac

echo "🖥️  Detected OS: $MACHINE"

# 🏷️ Set profile name (default or from command line argument)
PROFILE_NAME=${1:-minikube-multinode}
echo "🚀 Setting up a multi-node Minikube cluster with profile: $PROFILE_NAME"

# 📦 Function to install dependencies based on OS
install_dependencies() {
    # Check if Minikube is installed
    if ! command -v minikube &> /dev/null; then
        echo "Minikube is not installed. Installing Minikube..."
        
        if [ "$MACHINE" == "Mac" ]; then
            # Install Minikube for macOS
            brew install minikube
        elif [ "$MACHINE" == "Linux" ]; then
            # Install Minikube for Linux
            echo "Installing Minikube for Linux..."
            curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
            sudo install minikube-linux-amd64 /usr/local/bin/minikube
            rm minikube-linux-amd64
        else
            echo "Unsupported OS. Please install Minikube manually and run this script again."
            exit 1
        fi
        
        if [ $? -ne 0 ]; then
            echo "Failed to install Minikube. Please install it manually and run this script again."
            exit 1
        fi
    else
        echo "Minikube is already installed."
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

# ⏹️ Stop any existing Minikube cluster with the same profile
echo "⏹️ Stopping any existing Minikube cluster with profile '$PROFILE_NAME'..."
minikube stop -p $PROFILE_NAME || true

# 🗑️ Delete any existing Minikube cluster with the same profile
echo "🗑️ Deleting any existing Minikube cluster with profile '$PROFILE_NAME'..."
minikube delete -p $PROFILE_NAME || true

# 🔢 Set the number of nodes for the cluster
NODE_COUNT=3  # 🖧 🖧 🖧

# 🚗 Determine the best driver to use
determine_driver() {
    # Check if we're running in a CI environment
    if [ -n "${CI}" ]; then
        echo "none"
        return
    fi

    # Check if docker is available
    if command -v docker &> /dev/null && docker info &> /dev/null; then
        echo "docker"
        return
    fi

    # For Linux, check if kvm2 is available
    if [ "$MACHINE" == "Linux" ] && lsmod | grep kvm &> /dev/null; then
        echo "kvm2"
        return
    fi

    # For macOS, check for hyperkit
    if [ "$MACHINE" == "Mac" ] && command -v hyperkit &> /dev/null; then
        echo "hyperkit"
        return
    fi

    # If all else fails, use virtualbox if it's available
    if command -v VBoxManage &> /dev/null; then
        echo "virtualbox"
        return
    fi

    # Default back to docker
    echo "docker"
}

# 🛞 Get the best driver
DRIVER=$(determine_driver)
echo "🚗 Using driver: $DRIVER"

# 🚀 Start a new Minikube cluster with multiple nodes and specific profile
echo "🚀 Starting a new Minikube cluster with $NODE_COUNT nodes and profile '$PROFILE_NAME'..."
minikube start -p $PROFILE_NAME --nodes=$NODE_COUNT --driver=$DRIVER --kubernetes-version=stable

# ✅ Verify the cluster status
echo "✅ Verifying cluster status..."
minikube status -p $PROFILE_NAME
kubectl get nodes

# 🧩 Enable addons (optional)
echo "🧩 Enabling useful addons..."
minikube addons enable dashboard -p $PROFILE_NAME      # 📊 Dashboard
minikube addons enable metrics-server -p $PROFILE_NAME # 📈 Metrics
minikube addons enable ingress -p $PROFILE_NAME        # 🌐 Ingress

# ℹ️ Print cluster info
echo "ℹ️ Cluster Information:"
kubectl cluster-info

echo "🎉 Multi-node Minikube cluster setup complete! 🎉"
echo "🏷️  Profile: $PROFILE_NAME"
echo "📊 To access the Kubernetes Dashboard, run: minikube dashboard -p $PROFILE_NAME"
echo "🔍 To access the cluster with kubectl, run: kubectl get nodes"
echo "⏸️  To stop this cluster, run: minikube stop -p $PROFILE_NAME"
echo "🗑️  To delete this cluster, run: minikube delete -p $PROFILE_NAME"
