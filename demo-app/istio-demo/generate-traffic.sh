#!/bin/bash

# 📊 Traffic Generation Script for Istio Demo

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}📋 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

ISTIO_NAMESPACE="istio-system"

print_status "Starting traffic generation for BookInfo application..."

# Check if the gateway is accessible
INGRESS_HOST=$(kubectl get svc istio-ingressgateway -n $ISTIO_NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
INGRESS_PORT=$(kubectl get svc istio-ingressgateway -n $ISTIO_NAMESPACE -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')

if [ -z "$INGRESS_HOST" ]; then
    INGRESS_HOST=$(kubectl get svc istio-ingressgateway -n $ISTIO_NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
fi

if [ -z "$INGRESS_HOST" ]; then
    print_warning "LoadBalancer IP not available. Starting port-forward..."
    kubectl port-forward -n $ISTIO_NAMESPACE svc/istio-ingressgateway 8080:80 &
    PF_PID=$!
    sleep 5
    GATEWAY_URL="http://localhost:8080"
else
    GATEWAY_URL="http://$INGRESS_HOST:$INGRESS_PORT"
fi

echo ""
echo "🌐 Gateway URL: $GATEWAY_URL"
echo "📊 Generating traffic to demonstrate Istio features..."
echo ""

# Function to generate traffic
generate_traffic() {
    local url=$1
    local user=$2
    local requests=$3
    
    echo "Sending $requests requests to $url as user: $user"
    
    for i in $(seq 1 $requests); do
        if [ "$user" != "anonymous" ]; then
            curl -s -o /dev/null -w "%{http_code}" -H "end-user: $user" "$url/productpage" || echo "Request failed"
        else
            curl -s -o /dev/null -w "%{http_code}" "$url/productpage" || echo "Request failed"
        fi
        echo -n "."
        sleep 0.5
    done
    echo ""
}

# Generate traffic with different users to trigger different routing rules
print_status "Generating traffic for different user scenarios..."

echo ""
echo "1. Anonymous user traffic (80% v1, 20% v2 reviews):"
generate_traffic "$GATEWAY_URL" "anonymous" 20

echo ""
echo "2. Jason user traffic (should route to v2 reviews):"
generate_traffic "$GATEWAY_URL" "jason" 10

echo ""
echo "3. Mixed user traffic:"
generate_traffic "$GATEWAY_URL" "alice" 10
generate_traffic "$GATEWAY_URL" "bob" 10

echo ""
print_status "Testing HTTPBin service..."

# Test HTTPBin service
echo "Testing circuit breaker with HTTPBin..."
for i in {1..10}; do
    kubectl exec -it $(kubectl get pod -l app=httpbin -o jsonpath='{.items[0].metadata.name}') -c httpbin -- curl -s -o /dev/null -w "%{http_code}" http://httpbin:8000/delay/1 || echo "Circuit breaker triggered"
    echo -n "."
    sleep 0.2
done
echo ""

echo ""
print_success "Traffic generation completed!"
echo ""
echo "📊 You can now view the traffic in:"
echo "   • Kiali:  ./access-kiali.sh"
echo "   • Jaeger: ./access-jaeger.sh"
echo "   • Grafana: kubectl port-forward -n istio-system svc/grafana 3000:3000"
echo ""
echo "🔄 To run continuous traffic generation:"
echo "   watch -n 1 'curl -s -o /dev/null $GATEWAY_URL/productpage'"

# Cleanup port forward if we started it
if [ ! -z "${PF_PID:-}" ]; then
    kill $PF_PID 2>/dev/null || true
fi
