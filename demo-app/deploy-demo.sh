#!/bin/bash
set -euo pipefail

# 🚀 Demo Application Deployment Script
#
# This script helps deploy a demo application to test your Kubernetes clusters

# 🎮 Check if we're in Minikube or Kind environment
if [ $# -lt 1 ]; then
  echo "❓ Please specify the environment: minikube or kind"
  echo "Usage: $0 minikube|kind [profile_or_cluster_name]"
  exit 1
fi

ENV_TYPE=$1
CLUSTER_NAME=${2:-""}

# Set default names if not provided
if [ -z "$CLUSTER_NAME" ]; then
  if [ "$ENV_TYPE" = "minikube" ]; then
    CLUSTER_NAME="minikube-multinode"
  elif [ "$ENV_TYPE" = "kind" ]; then
    CLUSTER_NAME="kind-multi-node"
  fi
fi

# 🧪 Validate environment
if [ "$ENV_TYPE" = "minikube" ]; then
  echo "🔍 Checking if Minikube profile exists: $CLUSTER_NAME"
  if ! minikube profile list | grep -q "$CLUSTER_NAME"; then
    echo "❌ Error: Minikube profile '$CLUSTER_NAME' not found!"
    exit 1
  fi
  
  # Make sure we're using the correct Minikube context
  echo "🔄 Setting Kubernetes context to Minikube profile: $CLUSTER_NAME"
  minikube profile "$CLUSTER_NAME"
  
elif [ "$ENV_TYPE" = "kind" ]; then
  echo "🔍 Checking if Kind cluster exists: $CLUSTER_NAME"
  if ! kind get clusters | grep -q "$CLUSTER_NAME"; then
    echo "❌ Error: Kind cluster '$CLUSTER_NAME' not found!"
    exit 1
  fi
  
  # Make sure we're using the correct Kind context
  echo -e "🔄 Setting Kubernetes context to Kind cluster: kind-$CLUSTER_NAME"
  kubectl config use-context "kind-$CLUSTER_NAME"
  
else
  echo "❌ Error: Unknown environment type. Please specify 'minikube' or 'kind'"
  exit 1
fi

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# 📦 Deploy the demo application
echo "🚀 Deploying the Online Boutique demo application..."
if [ ! -f "$SCRIPT_DIR/demo-app.yaml" ]; then
    echo "❌ Error: demo-app.yaml not found at $SCRIPT_DIR/demo-app.yaml"
    exit 1
fi
kubectl apply -f "$SCRIPT_DIR/demo-app.yaml"

# 👮‍♀️ For Minikube dashboard, create admin account if needed
if [ "$ENV_TYPE" = "minikube" ]; then
  # Enable the dashboard if it's not already enabled
  echo "📊 Ensuring Kubernetes Dashboard is enabled..."
  minikube addons enable dashboard -p "$CLUSTER_NAME"
  
  # Create admin user for the dashboard
  echo "👤 Creating admin user for Kubernetes Dashboard..."
  if [ ! -f "$SCRIPT_DIR/k8s-dashboard.yaml" ]; then
      echo "⚠️  Warning: k8s-dashboard.yaml not found, skipping dashboard setup"
  else
      kubectl apply -f "$SCRIPT_DIR/k8s-dashboard.yaml"
      
      # Wait for the service account to be ready
      echo "⏱️ Waiting for dashboard service account..."
      sleep 3
      
      # Get the authentication token
      echo "🔑 Getting authentication token for Dashboard..."
      kubectl -n kubernetes-dashboard create token admin-user 2>/dev/null || echo "⚠️  Token generation failed. Try manually: kubectl -n kubernetes-dashboard create token admin-user"
  fi
  
  # Show instructions for accessing the dashboard
  echo ""
  echo "🌟 To access the Kubernetes Dashboard, run:"
  echo "minikube dashboard -p $CLUSTER_NAME"
fi

# 🌐 Wait for the deployment to be ready
echo "⏱️ Waiting for the demo application to be ready..."
kubectl rollout status deployment/microservices-demo --timeout=300s || echo "⚠️  Warning: Deployment rollout did not complete within timeout"

# 🔗 Show access information based on environment
echo ""
echo "✅ Demo Application Deployment Complete!"
echo ""

if [ "$ENV_TYPE" = "minikube" ]; then
  echo "🌐 To access the demo application, run:"
  echo "minikube service frontend -p $CLUSTER_NAME"
  echo ""
  echo "Or access via Ingress (may require tunnel):"
  echo "minikube tunnel -p $CLUSTER_NAME"
  echo "Then visit: http://localhost/"
elif [ "$ENV_TYPE" = "kind" ]; then
  echo "🌐 To access the demo application:"
  echo "Visit: http://localhost/"
  echo "(The Kind Ingress Controller is already configured to expose ports 80 and 443)"
fi

echo ""
echo "🧹 To clean up the demo application, run:"
echo "kubectl delete -f demo-app.yaml"
if [ "$ENV_TYPE" = "minikube" ]; then
  echo "kubectl delete -f k8s-dashboard.yaml"
fi
