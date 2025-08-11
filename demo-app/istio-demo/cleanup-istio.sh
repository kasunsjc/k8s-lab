#!/bin/bash

# 🧹 Istio Demo Cleanup Script

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

ISTIO_NAMESPACE="istio-system"
BOOKINFO_NAMESPACE="default"

cleanup_applications() {
    print_status "Cleaning up sample applications..."
    
    kubectl delete -f bookinfo-app.yaml --ignore-not-found=true
    kubectl delete -f httpbin.yaml --ignore-not-found=true
    kubectl delete -f istio-gateway.yaml --ignore-not-found=true
    kubectl delete -f traffic-management.yaml --ignore-not-found=true
    kubectl delete -f security-policies.yaml --ignore-not-found=true
    
    print_success "Sample applications cleaned up"
}

cleanup_istio_addons() {
    print_status "Cleaning up Istio addons..."
    
    if [ -d "./addons" ]; then
        kubectl delete -f ./addons/ --ignore-not-found=true
        rm -rf ./addons
    fi
    
    print_success "Istio addons cleaned up"
}

cleanup_istio_helm() {
    print_status "Uninstalling Istio components via Helm..."
    
    # Uninstall in reverse order
    helm uninstall istio-ingressgateway -n $ISTIO_NAMESPACE --ignore-not-found 2>/dev/null || true
    helm uninstall istiod -n $ISTIO_NAMESPACE --ignore-not-found 2>/dev/null || true
    helm uninstall istio-base -n $ISTIO_NAMESPACE --ignore-not-found 2>/dev/null || true
    
    print_success "Istio Helm releases uninstalled"
}

cleanup_namespaces() {
    print_status "Cleaning up namespaces and labels..."
    
    # Remove istio injection label from default namespace
    kubectl label namespace $BOOKINFO_NAMESPACE istio-injection- --ignore-not-found=true
    
    # Wait for pods to be terminated before deleting namespace
    print_status "Waiting for pods to terminate..."
    kubectl wait --for=delete pods --all -n $ISTIO_NAMESPACE --timeout=300s || true
    
    # Delete istio-system namespace
    kubectl delete namespace $ISTIO_NAMESPACE --ignore-not-found=true
    
    print_success "Namespaces cleaned up"
}

cleanup_crds() {
    print_status "Cleaning up Istio CRDs..."
    
    # Delete Istio CRDs
    kubectl get crd -o name | grep --color=never 'istio.io' | xargs kubectl delete --ignore-not-found=true
    
    print_success "Istio CRDs cleaned up"
}

show_final_status() {
    print_status "Final cleanup verification..."
    
    echo ""
    echo "Remaining Istio resources:"
    kubectl get all -n $ISTIO_NAMESPACE 2>/dev/null || echo "No resources found in istio-system namespace"
    
    echo ""
    echo "Remaining Istio CRDs:"
    kubectl get crd | grep istio || echo "No Istio CRDs found"
    
    echo ""
    print_success "Istio demo cleanup completed!"
}

confirm_cleanup() {
    echo "🧹 This will completely remove the Istio demo and all its components."
    echo ""
    echo "This includes:"
    echo "  • Sample applications (BookInfo, HTTPBin)"
    echo "  • Istio control plane (istiod)"
    echo "  • Istio gateways"
    echo "  • Istio addons (Kiali, Jaeger, Grafana, Prometheus)"
    echo "  • Istio CRDs"
    echo "  • istio-system namespace"
    echo ""
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cleanup cancelled."
        exit 0
    fi
}

main() {
    echo "🧹 Istio Service Mesh Demo Cleanup"
    echo "=================================="
    
    confirm_cleanup
    
    cleanup_applications
    cleanup_istio_addons
    cleanup_istio_helm
    cleanup_namespaces
    cleanup_crds
    
    echo ""
    show_final_status
}

# Run main function
main "$@"
