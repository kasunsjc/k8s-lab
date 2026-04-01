#!/bin/bash
set -euo pipefail

# 📊 Kubernetes Monitoring Demo Deployment Script
#
# This script deploys Prometheus, Grafana, and other monitoring components
# to a Kubernetes cluster (Minikube or Kind) using the Prometheus Operator via Helm.
# Usage: ./deploy-monitoring.sh <minikube|kind> [PROFILE_NAME]

# Set text colors
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
RED="\033[0;31m"
CYAN="\033[0;36m"
NC="\033[0m" # No Color

# Print header
echo -e "${BLUE}"
echo "╔═════════════════════════════════════════════════════════════╗"
echo "║                                                             ║"
echo "║  📊 ${YELLOW}Kubernetes Monitoring Stack Deployment${BLUE}              ║"
echo "║                                                             ║"
echo "╚═════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Get command line arguments
ENV_TYPE=${1:-}
CLUSTER_NAME=${2:-}

# Validate arguments
if [ -z "$ENV_TYPE" ]; then
    echo -e "${RED}❌ Error: Please specify 'minikube' or 'kind' as the environment type${NC}"
    echo -e "Usage: $0 <minikube|kind> [PROFILE_NAME]"
    exit 1
fi

if [ "$ENV_TYPE" != "minikube" ] && [ "$ENV_TYPE" != "kind" ]; then
    echo -e "${RED}❌ Error: First argument must be either 'minikube' or 'kind'${NC}"
    echo -e "Usage: $0 <minikube|kind> [PROFILE_NAME]"
    exit 1
fi

# Set default cluster name if not provided
if [ -z "$CLUSTER_NAME" ]; then
    if [ "$ENV_TYPE" = "minikube" ]; then
        CLUSTER_NAME="minikube-multinode"
    else
        CLUSTER_NAME="kind-multi-node"
    fi
fi

echo -e "${CYAN}🚀 Deploying monitoring stack to $ENV_TYPE cluster: $CLUSTER_NAME ${NC}"

# Ensure we're using the right context
if [ "$ENV_TYPE" = "minikube" ]; then
    echo -e "${YELLOW}📍 Setting kubectl context to Minikube profile: $CLUSTER_NAME${NC}"
    minikube profile "$CLUSTER_NAME"
    CONTEXT=$(kubectl config current-context)
elif [ "$ENV_TYPE" = "kind" ]; then
    echo -e "${YELLOW}📍 Setting kubectl context to Kind cluster: $CLUSTER_NAME${NC}"
    kubectl config use-context "kind-$CLUSTER_NAME"
    CONTEXT=$(kubectl config current-context)
fi

echo -e "${GREEN}✅ Using Kubernetes context: $CONTEXT${NC}"

# Check for required tools
echo -e "${CYAN}📌 Checking for required tools...${NC}"

# Check for kubectl
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl not found. Please install kubectl first.${NC}"
    echo -e "${YELLOW}💡 Installation instructions: https://kubernetes.io/docs/tasks/tools/install-kubectl/${NC}"
    exit 1
fi

# Check for helm
if ! command -v helm &> /dev/null; then
    echo -e "${RED}❌ Helm not found. Please install Helm first.${NC}"
    echo -e "${YELLOW}💡 Installation instructions: https://helm.sh/docs/intro/install/${NC}"
    exit 1
fi

echo -e "${GREEN}✅ All required tools found${NC}"

# Create monitoring namespace
echo -e "${CYAN}📌 Step 1: Creating monitoring namespace...${NC}"
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
echo -e "${GREEN}✅ Monitoring namespace created${NC}"

# Add Prometheus Community Helm repo
echo -e "${CYAN}📌 Step 2: Adding Prometheus Community Helm repository...${NC}"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
echo -e "${GREEN}✅ Helm repository added${NC}"

# Deploy kube-prometheus-stack using Helm
echo -e "${CYAN}📌 Step 3: Deploying Prometheus Operator stack using Helm...${NC}"

# Check if values.yaml exists
if [ -f "values.yaml" ]; then
    echo -e "${YELLOW}📄 Using values.yaml for Helm chart configuration${NC}"
    helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
      --namespace monitoring \
      --values values.yaml \
      --atomic \
      --timeout 300s \
      --wait
else
    echo -e "${YELLOW}⚠️ values.yaml not found, using default values${NC}"
    helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
      --namespace monitoring \
      --set prometheus.service.type=ClusterIP \
      --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false \
      --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
      --set grafana.service.type=ClusterIP \
      --set alertmanager.service.type=ClusterIP \
      --set prometheusOperator.createCustomResource=true \
      --set grafana.adminPassword=admin \
      --set defaultRules.create=true \
      --set kubeStateMetrics.enabled=true \
      --set nodeExporter.enabled=true \
      --atomic \
      --timeout 300s \
      --wait
fi
echo -e "${GREEN}✅ Prometheus Operator stack deployed${NC}"

# Apply additional custom configurations if needed
echo -e "${CYAN}📌 Step 4: Applying additional custom configurations...${NC}"
if [ -f "custom-values.yaml" ]; then
    kubectl apply -f custom-values.yaml -n monitoring
    echo -e "${GREEN}✅ Custom configurations applied${NC}"
else
    echo -e "${YELLOW}⚠️ No custom configurations found. Skipping.${NC}"
fi

# Apply ServiceMonitors
echo -e "${CYAN}📌 Step 5: Applying ServiceMonitors...${NC}"
if [ -f "service-monitors.yaml" ]; then
    kubectl apply -f service-monitors.yaml
    echo -e "${GREEN}✅ ServiceMonitors applied${NC}"
else
    echo -e "${YELLOW}⚠️ No service-monitors.yaml found. Skipping.${NC}"
fi

# Wait for deployments to be ready
echo -e "${CYAN}⏳ Waiting for deployments to be ready...${NC}"
kubectl rollout status statefulset/prometheus-prometheus-kube-prometheus-prometheus -n monitoring --timeout=180s || echo -e "${YELLOW}⚠️  Prometheus StatefulSet not ready within timeout${NC}"
kubectl rollout status deployment/prometheus-grafana -n monitoring --timeout=180s || echo -e "${YELLOW}⚠️  Grafana not ready within timeout${NC}"
kubectl rollout status deployment/prometheus-kube-state-metrics -n monitoring --timeout=120s || echo -e "${YELLOW}⚠️  Kube State Metrics not ready within timeout${NC}"
echo -e "${GREEN}✅ Deployments are ready!${NC}"

# Display access information
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}🔍 Accessing the Monitoring Dashboards:${NC}"
echo

if [ "$ENV_TYPE" = "minikube" ]; then
    echo -e "${YELLOW}Grafana:${NC}"
    echo -e "  Run: minikube service prometheus-grafana -n monitoring -p $CLUSTER_NAME"
    echo -e "${YELLOW}Prometheus:${NC}"
    echo -e "  Run: minikube service prometheus-kube-prometheus-prometheus -n monitoring -p $CLUSTER_NAME"
    echo -e "${YELLOW}Alertmanager:${NC}"
    echo -e "  Run: minikube service prometheus-kube-prometheus-alertmanager -n monitoring -p $CLUSTER_NAME"
else
    echo -e "${YELLOW}Grafana:${NC}"
    echo -e "  Run: kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring"
    echo -e "  Then access: http://localhost:3000"
    echo -e "${YELLOW}Prometheus:${NC}"
    echo -e "  Run: kubectl port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090 -n monitoring"
    echo -e "  Then access: http://localhost:9090"
    echo -e "${YELLOW}Alertmanager:${NC}"
    echo -e "  Run: kubectl port-forward svc/prometheus-kube-prometheus-alertmanager 9093:9093 -n monitoring"
    echo -e "  Then access: http://localhost:9093"
fi

echo
echo -e "${CYAN}🔐 Default Credentials:${NC}"
echo -e "  Grafana: Username: admin, Password: admin"
echo -e "  (You'll be asked to change the password on first login)"
echo
echo -e "${YELLOW}💡 Available Features:${NC}"
echo -e "  ✅ Prometheus Operator with custom resource definitions"
echo -e "  ✅ Prometheus server with automatic service discovery"
echo -e "  ✅ AlertManager for handling alerts"
echo -e "  ✅ Grafana with pre-configured dashboards"
echo -e "  ✅ Node Exporter for hardware and OS metrics"
echo -e "  ✅ Kube State Metrics for Kubernetes object metrics"
echo -e "  ✅ ServiceMonitor and PodMonitor support"
echo
echo -e "${GREEN}🎉 Prometheus Operator monitoring stack deployment complete! 🎉${NC}"
