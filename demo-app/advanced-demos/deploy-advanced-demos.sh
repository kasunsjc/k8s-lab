#!/bin/bash

# 🚀 Advanced Demo Applications Deployment Script
#
# This script helps deploy advanced Kubernetes demo applications

# Set text colors
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
RED="\033[0;31m"
PURPLE="\033[0;35m"
CYAN="\033[0;36m"
NC="\033[0m" # No Color

# Print header
echo -e "${BLUE}"
echo "╔═════════════════════════════════════════════════════════════╗"
echo "║                                                             ║"
echo "║  🚀 ${YELLOW}Advanced Kubernetes Demos Deployment${BLUE}                 ║"
echo "║                                                             ║"
echo "╚═════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# 🎮 Check if we're in Minikube or Kind environment
if [ $# -lt 1 ]; then
  echo -e "${RED}❓ Please specify the environment: minikube or kind${NC}"
  echo "Usage: $0 minikube|kind [profile_or_cluster_name] [demo_type]"
  echo ""
  echo -e "Available demo types:"
  echo -e "  ${GREEN}all${NC}            - Deploy all demo applications"
  echo -e "  ${GREEN}stateful${NC}       - Deploy MongoDB StatefulSet demo"
  echo -e "  ${GREEN}hpa${NC}            - Deploy HorizontalPodAutoscaler demo"
  echo -e "  ${GREEN}config-secret${NC}  - Deploy ConfigMap and Secret demo"
  exit 1
fi

ENV_TYPE=$1
CLUSTER_NAME=${2:-""}
DEMO_TYPE=${3:-"all"}

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
  echo -e "${CYAN}🔍 Checking if Minikube profile exists: $CLUSTER_NAME${NC}"
  if ! minikube profile list | grep -q "$CLUSTER_NAME"; then
    echo -e "${RED}❌ Error: Minikube profile '$CLUSTER_NAME' not found!${NC}"
    exit 1
  fi
  
  # Make sure we're using the correct Minikube context
  echo -e "${YELLOW}🔄 Setting Kubernetes context to Minikube profile: $CLUSTER_NAME${NC}"
  minikube profile $CLUSTER_NAME
  
elif [ "$ENV_TYPE" = "kind" ]; then
  echo -e "${CYAN}🔍 Checking if Kind cluster exists: $CLUSTER_NAME${NC}"
  if ! kind get clusters | grep -q "$CLUSTER_NAME"; then
    echo -e "${RED}❌ Error: Kind cluster '$CLUSTER_NAME' not found!${NC}"
    exit 1
  fi
  
  # Make sure we're using the correct Kind context
  echo -e "${YELLOW}🔄 Setting Kubernetes context to Kind cluster: kind-$CLUSTER_NAME${NC}"
  kubectl config use-context kind-$CLUSTER_NAME
  
else
  echo -e "${RED}❌ Error: Unknown environment type. Please specify 'minikube' or 'kind'${NC}"
  exit 1
fi

# Make sure the metrics server is running (needed for HPA demo)
if [ "$DEMO_TYPE" = "all" ] || [ "$DEMO_TYPE" = "hpa" ]; then
  echo -e "${YELLOW}📊 Ensuring Metrics Server is enabled...${NC}"
  if [ "$ENV_TYPE" = "minikube" ]; then
    minikube addons enable metrics-server -p $CLUSTER_NAME
  elif [ "$ENV_TYPE" = "kind" ]; then
    # Check if metrics-server is already deployed
    if ! kubectl get deployment metrics-server -n kube-system &> /dev/null; then
      echo -e "${YELLOW}📊 Installing Metrics Server for Kind...${NC}"
      kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
      # Patch metrics-server to work with kind (insecure TLS)
      kubectl patch deployment metrics-server -n kube-system --type=json \
        -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
    fi
  fi
fi

# 📦 Deploy the demo applications
# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ "$DEMO_TYPE" = "all" ] || [ "$DEMO_TYPE" = "stateful" ]; then
  echo -e "${GREEN}🚀 Deploying MongoDB StatefulSet demo...${NC}"
  kubectl apply -f "$SCRIPT_DIR/stateful-mongodb.yaml"
  echo -e "${CYAN}✅ MongoDB StatefulSet demo deployed!${NC}"
  echo ""
fi

if [ "$DEMO_TYPE" = "all" ] || [ "$DEMO_TYPE" = "hpa" ]; then
  echo -e "${GREEN}🚀 Deploying HorizontalPodAutoscaler demo...${NC}"
  kubectl apply -f "$SCRIPT_DIR/hpa-demo.yaml"
  echo -e "${CYAN}✅ HPA demo deployed!${NC}"
  echo ""
fi

if [ "$DEMO_TYPE" = "all" ] || [ "$DEMO_TYPE" = "config-secret" ]; then
  echo -e "${GREEN}🚀 Deploying ConfigMap and Secret demo...${NC}"
  kubectl apply -f "$SCRIPT_DIR/configmap-secret-demo.yaml"
  echo -e "${CYAN}✅ ConfigMap and Secret demo deployed!${NC}"
  echo ""
fi

# Wait for resources to be ready
echo -e "${YELLOW}⏱️ Waiting for demo applications to be ready...${NC}"

if [ "$DEMO_TYPE" = "all" ] || [ "$DEMO_TYPE" = "stateful" ]; then
  echo -e "${CYAN}🔄 Waiting for MongoDB StatefulSet...${NC}"
  kubectl wait --for=condition=Ready pod/mongodb-0 --timeout=120s
  kubectl wait --for=condition=Ready pod/mongo-express-0 --timeout=120s || true
fi

if [ "$DEMO_TYPE" = "all" ] || [ "$DEMO_TYPE" = "hpa" ]; then
  echo -e "${CYAN}🔄 Waiting for HPA demo...${NC}"
  kubectl wait --for=condition=available --timeout=120s deployment/php-apache
fi

if [ "$DEMO_TYPE" = "all" ] || [ "$DEMO_TYPE" = "config-secret" ]; then
  echo -e "${CYAN}🔄 Waiting for ConfigMap and Secret demo...${NC}"
  kubectl wait --for=condition=available --timeout=120s deployment/configmap-secret-demo
fi

# 🔗 Show access information based on environment
echo -e ""
echo -e "${GREEN}✅ Advanced Demo Applications Deployment Complete!${NC}"
echo -e ""

if [ "$ENV_TYPE" = "minikube" ]; then
  echo -e "${CYAN}🌐 To access the demo applications, run:${NC}"
  echo -e "${YELLOW}minikube tunnel -p $CLUSTER_NAME${NC}"
  echo -e "Then visit:"
  echo -e "- MongoDB Express UI: http://localhost/mongo-express"
  echo -e "- HPA Demo: http://localhost/php-apache"
  echo -e "- ConfigMap & Secret Demo: http://localhost/config-demo"
  echo -e ""
  echo -e "${CYAN}💡 To test the HPA demo, you can generate load with:${NC}"
  echo -e "${YELLOW}kubectl run -i --tty load-generator --rm --image=busybox --restart=Never -- /bin/sh -c \"while sleep 0.01; do wget -q -O- http://php-apache; done\"${NC}"
elif [ "$ENV_TYPE" = "kind" ]; then
  echo -e "${CYAN}🌐 To access the demo applications:${NC}"
  echo -e "- MongoDB Express UI: http://localhost/mongo-express"
  echo -e "- HPA Demo: http://localhost/php-apache"
  echo -e "- ConfigMap & Secret Demo: http://localhost/config-demo"
  echo -e ""
  echo -e "${CYAN}💡 To test the HPA demo, you can generate load with:${NC}"
  echo -e "${YELLOW}kubectl run -i --tty load-generator --rm --image=busybox --restart=Never -- /bin/sh -c \"while sleep 0.01; do wget -q -O- http://php-apache; done\"${NC}"
fi

echo -e ""
echo -e "${GREEN}📊 To monitor the HPA scaling:${NC}"
echo -e "${YELLOW}kubectl get hpa php-apache --watch${NC}"
echo -e ""
echo -e "${GREEN}📊 To see the MongoDB StatefulSet pods:${NC}"
echo -e "${YELLOW}kubectl get statefulset,pods -l app=mongodb${NC}"
echo -e ""
echo -e "${GREEN}🔍 To explore the ConfigMap and Secret demo:${NC}"
echo -e "${YELLOW}POD=\$(kubectl get pod -l app=configmap-secret-demo -o jsonpath='{.items[0].metadata.name}')${NC}"
echo -e "${YELLOW}kubectl exec -it \$POD -- sh${NC}"
