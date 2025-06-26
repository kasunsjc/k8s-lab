#!/bin/bash

# 📊 Kubernetes Monitoring Test Script
#
# This script runs tests against the deployed monitoring stack
# to verify that it's working correctly.
# Usage: ./test-monitoring.sh <minikube|kind> [PROFILE_NAME]

set -e

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
echo "║  🧪 ${YELLOW}Kubernetes Monitoring Stack Tests${BLUE}                   ║"
echo "║                                                             ║"
echo "╚═════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Get command line arguments
ENV_TYPE=$1
CLUSTER_NAME=$2

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

# Ensure we're using the right context
if [ "$ENV_TYPE" = "minikube" ]; then
    echo -e "${YELLOW}📍 Setting kubectl context to Minikube profile: $CLUSTER_NAME${NC}"
    minikube profile $CLUSTER_NAME
    CONTEXT=$(kubectl config current-context)
elif [ "$ENV_TYPE" = "kind" ]; then
    echo -e "${YELLOW}📍 Setting kubectl context to Kind cluster: $CLUSTER_NAME${NC}"
    kubectl config use-context "kind-$CLUSTER_NAME"
    CONTEXT=$(kubectl config current-context)
fi

echo -e "${GREEN}✅ Using Kubernetes context: $CONTEXT${NC}"

# Verify monitoring components are running
echo -e "${CYAN}📌 Checking if monitoring components are running...${NC}"
if ! kubectl get namespace monitoring &> /dev/null; then
    echo -e "${RED}❌ The monitoring namespace doesn't exist!${NC}"
    echo -e "${YELLOW}💡 Run ./deploy-monitoring.sh first to deploy the monitoring stack${NC}"
    exit 1
fi

# Check if all deployments are ready
echo -e "${CYAN}📌 Test 1: Checking deployments...${NC}"
DEPLOYMENTS=$(kubectl get deployments -n monitoring -o custom-columns=NAME:.metadata.name --no-headers)

for deployment in $DEPLOYMENTS; do
    READY=$(kubectl get deployment $deployment -n monitoring -o jsonpath='{.status.readyReplicas}')
    DESIRED=$(kubectl get deployment $deployment -n monitoring -o jsonpath='{.spec.replicas}')
    
    echo -n "Deployment $deployment: "
    if [ "$READY" == "$DESIRED" ]; then
        echo -e "${GREEN}✅ Ready ($READY/$DESIRED)${NC}"
    else
        echo -e "${RED}❌ Not ready ($READY/$DESIRED)${NC}"
        TEST_FAILED=true
    fi
done

# Test Prometheus API
echo -e "${CYAN}📌 Test 2: Checking Prometheus API...${NC}"

# Function to cleanup port forwarding processes
cleanup_port_forwarding() {
    if [ ! -z "$PORT_FWD_PID" ]; then
        kill $PORT_FWD_PID 2>/dev/null || true
    fi
}

# Setup trap to ensure cleanup happens
trap cleanup_port_forwarding EXIT

# Forward the port in the background
echo -e "${YELLOW}🔄 Setting up port forwarding for Prometheus...${NC}"
kubectl port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090 -n monitoring &> /dev/null &
PORT_FWD_PID=$!

# Wait for port forwarding to be established
sleep 5

# Test if Prometheus API is accessible
echo -n "Prometheus API accessibility: "
PROM_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9090/api/v1/status/buildinfo || echo "Failed")
if [ "$PROM_STATUS" = "200" ]; then
    echo -e "${GREEN}✅ Accessible${NC}"
else
    echo -e "${RED}❌ Failed to access (status code: $PROM_STATUS)${NC}"
    TEST_FAILED=true
fi

# Check if targets are being scraped
echo -n "Prometheus targets: "
TARGETS_JSON=$(curl -s http://localhost:9090/api/v1/targets 2>/dev/null || echo "{}")
if echo "$TARGETS_JSON" | grep -q '"status":"up"'; then
    echo -e "${GREEN}✅ Active targets found${NC}"
else
    echo -e "${RED}❌ No active targets found${NC}"
    TEST_FAILED=true
fi

# Clean up port forwarding
cleanup_port_forwarding
unset PORT_FWD_PID

# Test Grafana API
echo -e "${CYAN}📌 Test 3: Checking Grafana API...${NC}"

# Forward the port in the background
echo -e "${YELLOW}🔄 Setting up port forwarding for Grafana...${NC}"
kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring &> /dev/null &
PORT_FWD_PID=$!

# Wait for port forwarding to be established
sleep 5

# Test if Grafana API is accessible
echo -n "Grafana API accessibility: "
GRAFANA_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/api/health || echo "Failed")
if [ "$GRAFANA_STATUS" = "200" ]; then
    echo -e "${GREEN}✅ Accessible${NC}"
else
    echo -e "${RED}❌ Failed to access (status code: $GRAFANA_STATUS)${NC}"
    TEST_FAILED=true
fi

# Check Grafana datasources
echo -n "Grafana datasources: "
if curl -s -u admin:admin http://localhost:3000/api/datasources 2>/dev/null | grep -q "prometheus"; then
    echo -e "${GREEN}✅ Prometheus datasource configured${NC}"
else
    echo -e "${RED}❌ Prometheus datasource not found${NC}"
    TEST_FAILED=true
fi

# Test importing a dashboard
if [ -f "test-dashboard.json" ]; then
    echo -n "Grafana dashboard import: "
    IMPORT_RESULT=$(curl -s -u admin:admin -H "Content-Type: application/json" -X POST -d @test-dashboard.json http://localhost:3000/api/dashboards/db 2>/dev/null)
    if echo "$IMPORT_RESULT" | grep -q "success"; then
        echo -e "${GREEN}✅ Test dashboard imported successfully${NC}"
    else
        echo -e "${YELLOW}⚠️ Could not import dashboard: $(echo $IMPORT_RESULT | grep -o '"message":"[^"]*"' || echo "Unknown error")${NC}"
        # Not failing the test for this as it's not critical
    fi
fi

# Clean up port forwarding
cleanup_port_forwarding
unset PORT_FWD_PID

# Test Alert Manager
echo -e "${CYAN}📌 Test 4: Checking AlertManager API...${NC}"

# Forward the port in the background
echo -e "${YELLOW}🔄 Setting up port forwarding for AlertManager...${NC}"
kubectl port-forward svc/prometheus-kube-prometheus-alertmanager 9093:9093 -n monitoring &> /dev/null &
PORT_FWD_PID=$!

# Wait for port forwarding to be established
sleep 5

# Test if AlertManager API is accessible
echo -n "AlertManager API accessibility: "
AM_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9093/api/v2/status || echo "Failed")
if [ "$AM_STATUS" = "200" ]; then
    echo -e "${GREEN}✅ Accessible${NC}"
else
    echo -e "${RED}❌ Failed to access (status code: $AM_STATUS)${NC}"
    TEST_FAILED=true
fi

# Clean up port forwarding
cleanup_port_forwarding
unset PORT_FWD_PID

# Test 5: Generate load and check if metrics are collected
echo -e "${CYAN}📌 Test 5: Generating load and checking metrics...${NC}"

# Create a simple load generator
echo -e "${YELLOW}🔄 Creating a load generator pod...${NC}"
kubectl create deployment load-generator --image=busybox -- /bin/sh -c "while true; do wget -q -O- http://kubernetes.default.svc.cluster.local || true; sleep 1; done" &> /dev/null || true

# Scale it up to generate more load
kubectl scale deployment load-generator --replicas=2 &> /dev/null || true

echo -e "${YELLOW}⏳ Waiting 30 seconds for metrics to be collected...${NC}"
sleep 30

# Forward the port in the background
kubectl port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090 -n monitoring &> /dev/null &
PORT_FWD_PID=$!

# Wait for port forwarding to be established
sleep 5

# Test if we can query metrics related to the load test
echo -n "Metrics for load generator: "
QUERY_RESULT=$(curl -s -G --data-urlencode 'query=container_cpu_usage_seconds_total{pod=~"load-generator.*"}' http://localhost:9090/api/v1/query 2>/dev/null || echo "{}")

if echo "$QUERY_RESULT" | grep -q '"resultType":"vector"'; then
    if echo "$QUERY_RESULT" | grep -q '"value":\['; then
        echo -e "${GREEN}✅ Metrics found${NC}"
    else
        echo -e "${YELLOW}⚠️ Query successful but no metrics found yet${NC}"
    fi
else
    echo -e "${RED}❌ Failed to query metrics${NC}"
    TEST_FAILED=true
fi

# Clean up load generator
echo -e "${YELLOW}🧹 Cleaning up load generator...${NC}"
kubectl delete deployment load-generator &> /dev/null || true

# Clean up port forwarding
cleanup_port_forwarding
unset PORT_FWD_PID

# Display final test results
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if [ "$TEST_FAILED" = true ]; then
    echo -e "${RED}❌ Some tests failed! Please check the output above for details.${NC}"
    exit 1
else
    echo -e "${GREEN}🎉 All tests passed! The monitoring stack is working correctly.${NC}"
fi
