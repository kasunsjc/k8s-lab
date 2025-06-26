#!/bin/bash

# 📊 Kubernetes Monitoring Dashboard Script
#
# This script opens the Grafana, Prometheus, and Alertmanager dashboards
# in a web browser by setting up port forwarding.
# Usage: ./start-monitoring.sh <minikube|kind> [PROFILE_NAME] [dashboard]

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
echo "║  🔍 ${YELLOW}Kubernetes Monitoring Dashboard Access${BLUE}              ║"
echo "║                                                             ║"
echo "╚═════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Get command line arguments
ENV_TYPE=$1
CLUSTER_NAME=$2
DASHBOARD=${3:-all}

# Validate arguments
if [ -z "$ENV_TYPE" ]; then
    echo -e "${RED}❌ Error: Please specify 'minikube' or 'kind' as the environment type${NC}"
    echo -e "Usage: $0 <minikube|kind> [PROFILE_NAME] [dashboard]"
    echo -e "Available dashboards: grafana, prometheus, alertmanager, all"
    exit 1
fi

if [ "$ENV_TYPE" != "minikube" ] && [ "$ENV_TYPE" != "kind" ]; then
    echo -e "${RED}❌ Error: First argument must be either 'minikube' or 'kind'${NC}"
    echo -e "Usage: $0 <minikube|kind> [PROFILE_NAME] [dashboard]"
    echo -e "Available dashboards: grafana, prometheus, alertmanager, all"
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

# Ensure we're using the right context
if [ "$ENV_TYPE" = "minikube" ]; then
    echo -e "${YELLOW}📍 Setting kubectl context to Minikube profile: $CLUSTER_NAME${NC}"
    minikube profile $CLUSTER_NAME
elif [ "$ENV_TYPE" = "kind" ]; then
    echo -e "${YELLOW}📍 Setting kubectl context to Kind cluster: $CLUSTER_NAME${NC}"
    kubectl config use-context "kind-$CLUSTER_NAME"
fi

# Verify monitoring components are running
echo -e "${CYAN}📌 Checking if monitoring components are running...${NC}"
if ! kubectl get namespace monitoring &> /dev/null; then
    echo -e "${RED}❌ The monitoring namespace doesn't exist!${NC}"
    echo -e "${YELLOW}💡 Run ./deploy-monitoring.sh first to deploy the monitoring stack${NC}"
    exit 1
fi

if ! kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana &> /dev/null; then
    echo -e "${RED}❌ Grafana pod not found!${NC}"
    echo -e "${YELLOW}💡 Make sure the Prometheus Operator stack is deployed correctly${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Monitoring components are running${NC}"

# Function to open dashboard in minikube
open_minikube_dashboard() {
    case $1 in
        grafana)
            echo -e "${CYAN}🔍 Opening Grafana dashboard...${NC}"
            minikube service prometheus-grafana -n monitoring -p $CLUSTER_NAME
            ;;
        prometheus)
            echo -e "${CYAN}🔍 Opening Prometheus dashboard...${NC}"
            minikube service prometheus-kube-prometheus-prometheus -n monitoring -p $CLUSTER_NAME
            ;;
        alertmanager)
            echo -e "${CYAN}🔍 Opening Alertmanager dashboard...${NC}"
            minikube service prometheus-kube-prometheus-alertmanager -n monitoring -p $CLUSTER_NAME
            ;;
        all)
            echo -e "${CYAN}🔍 Opening all dashboards in separate terminals...${NC}"
            open_minikube_dashboard grafana
            open_minikube_dashboard prometheus
            open_minikube_dashboard alertmanager
            ;;
        *)
            echo -e "${RED}❌ Invalid dashboard: $1${NC}"
            echo -e "Available dashboards: grafana, prometheus, alertmanager, all"
            exit 1
            ;;
    esac
}

# Function to open dashboard in kind using port-forwarding
open_kind_dashboard() {
    case $1 in
        grafana)
            echo -e "${CYAN}🔍 Setting up port forwarding for Grafana (http://localhost:3000)...${NC}"
            echo -e "${YELLOW}💡 Default credentials: admin / admin${NC}"
            kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring
            ;;
        prometheus)
            echo -e "${CYAN}🔍 Setting up port forwarding for Prometheus (http://localhost:9090)...${NC}"
            kubectl port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090 -n monitoring
            ;;
        alertmanager)
            echo -e "${CYAN}🔍 Setting up port forwarding for Alertmanager (http://localhost:9093)...${NC}"
            kubectl port-forward svc/prometheus-kube-prometheus-alertmanager 9093:9093 -n monitoring
            ;;
        all)
            echo -e "${CYAN}🔍 To open all dashboards, please run separate commands in different terminals:${NC}"
            echo -e "${YELLOW}Grafana:${NC} $0 $ENV_TYPE $CLUSTER_NAME grafana"
            echo -e "${YELLOW}Prometheus:${NC} $0 $ENV_TYPE $CLUSTER_NAME prometheus"
            echo -e "${YELLOW}Alertmanager:${NC} $0 $ENV_TYPE $CLUSTER_NAME alertmanager"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Invalid dashboard: $1${NC}"
            echo -e "Available dashboards: grafana, prometheus, alertmanager, all"
            exit 1
            ;;
    esac
}

# Open the selected dashboard
if [ "$ENV_TYPE" = "minikube" ]; then
    open_minikube_dashboard $DASHBOARD
elif [ "$ENV_TYPE" = "kind" ]; then
    open_kind_dashboard $DASHBOARD
fi
