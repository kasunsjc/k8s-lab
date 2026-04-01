#!/bin/bash

# 🔍 Jaeger Tracing Dashboard Access Script

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}📋 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

ISTIO_NAMESPACE="istio-system"

print_status "Checking if Jaeger is running..."

# Check if Jaeger pod is running
if ! kubectl get pod -n $ISTIO_NAMESPACE -l app=jaeger | grep -q Running; then
    echo "❌ Jaeger is not running. Please run ./deploy-istio.sh first."
    exit 1
fi

print_success "Jaeger is running"

echo ""
echo "🌐 Starting port-forward to Jaeger dashboard..."
echo "📊 Jaeger will be available at: http://localhost:16686"
echo ""
echo "Press Ctrl+C to stop port forwarding"
echo ""

# Start port forwarding
kubectl port-forward -n $ISTIO_NAMESPACE svc/jaeger 16686:16686
