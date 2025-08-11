#!/bin/bash

# 🧪 Istio Demo Test Script
#
# This script validates the Istio deployment and runs comprehensive tests

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
FAILED_TESTS=0

test_namespace_exists() {
    print_status "Testing if istio-system namespace exists..."
    if kubectl get namespace $ISTIO_NAMESPACE &> /dev/null; then
        print_success "istio-system namespace exists"
    else
        print_error "istio-system namespace not found"
        ((FAILED_TESTS++))
    fi
}

test_istio_components() {
    print_status "Testing Istio control plane components..."
    
    # Test istiod deployment
    if kubectl get deployment istiod -n $ISTIO_NAMESPACE &> /dev/null; then
        if kubectl wait --for=condition=available deployment/istiod -n $ISTIO_NAMESPACE --timeout=60s &> /dev/null; then
            print_success "istiod is running and available"
        else
            print_error "istiod is not available"
            ((FAILED_TESTS++))
        fi
    else
        print_error "istiod deployment not found"
        ((FAILED_TESTS++))
    fi
    
    # Test ingress gateway
    if kubectl get deployment istio-ingressgateway -n $ISTIO_NAMESPACE &> /dev/null; then
        if kubectl wait --for=condition=available deployment/istio-ingressgateway -n $ISTIO_NAMESPACE --timeout=60s &> /dev/null; then
            print_success "istio-ingressgateway is running and available"
        else
            print_error "istio-ingressgateway is not available"
            ((FAILED_TESTS++))
        fi
    else
        print_error "istio-ingressgateway deployment not found"
        ((FAILED_TESTS++))
    fi
}

test_bookinfo_app() {
    print_status "Testing BookInfo application components..."
    
    local services=("productpage" "details" "reviews" "ratings")
    
    for service in "${services[@]}"; do
        if kubectl get service $service -n $BOOKINFO_NAMESPACE &> /dev/null; then
            print_success "$service service exists"
        else
            print_error "$service service not found"
            ((FAILED_TESTS++))
        fi
        
        if kubectl get deployment -l app=$service -n $BOOKINFO_NAMESPACE &> /dev/null; then
            if kubectl wait --for=condition=available deployment -l app=$service -n $BOOKINFO_NAMESPACE --timeout=60s &> /dev/null; then
                print_success "$service deployment is available"
            else
                print_error "$service deployment is not available"
                ((FAILED_TESTS++))
            fi
        else
            print_error "$service deployment not found"
            ((FAILED_TESTS++))
        fi
    done
}

test_istio_injection() {
    print_status "Testing sidecar injection..."
    
    # Check if namespace is labeled for injection
    local injection_label=$(kubectl get namespace $BOOKINFO_NAMESPACE -o jsonpath='{.metadata.labels.istio-injection}' 2>/dev/null || echo "")
    
    if [ "$injection_label" = "enabled" ]; then
        print_success "Namespace is labeled for istio injection"
    else
        print_error "Namespace is not labeled for istio injection"
        ((FAILED_TESTS++))
    fi
    
    # Check if pods have sidecars
    local pod_count=$(kubectl get pods -n $BOOKINFO_NAMESPACE -o jsonpath='{.items[*].spec.containers[*].name}' | tr ' ' '\n' | grep -c istio-proxy || echo 0)
    
    if [ "$pod_count" -gt 0 ]; then
        print_success "Found $pod_count istio-proxy sidecars"
    else
        print_error "No istio-proxy sidecars found"
        ((FAILED_TESTS++))
    fi
}

test_gateway_configuration() {
    print_status "Testing Gateway and VirtualService configuration..."
    
    if kubectl get gateway bookinfo-gateway -n $BOOKINFO_NAMESPACE &> /dev/null; then
        print_success "bookinfo-gateway exists"
    else
        print_error "bookinfo-gateway not found"
        ((FAILED_TESTS++))
    fi
    
    if kubectl get virtualservice bookinfo -n $BOOKINFO_NAMESPACE &> /dev/null; then
        print_success "bookinfo VirtualService exists"
    else
        print_error "bookinfo VirtualService not found"
        ((FAILED_TESTS++))
    fi
}

test_application_connectivity() {
    print_status "Testing application connectivity..."
    
    # Get ingress gateway service info
    local ingress_host=$(kubectl get svc istio-ingressgateway -n $ISTIO_NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    local ingress_port=$(kubectl get svc istio-ingressgateway -n $ISTIO_NAMESPACE -o jsonpath='{.spec.ports[?(@.name=="http2")].port}' 2>/dev/null || echo "80")
    
    if [ -z "$ingress_host" ]; then
        ingress_host=$(kubectl get svc istio-ingressgateway -n $ISTIO_NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
    fi
    
    if [ -z "$ingress_host" ]; then
        print_warning "LoadBalancer IP not available, testing with port-forward..."
        kubectl port-forward -n $ISTIO_NAMESPACE svc/istio-ingressgateway 8080:80 &
        local pf_pid=$!

        # Wait for port-forward to be ready (max 15 seconds)
        for i in {1..15}; do
            if nc -z localhost 8080; then
                break
            fi
            sleep 1
        done

        if curl -s -f -o /dev/null "http://localhost:8080/productpage"; then
            print_success "Application is accessible via port-forward"
        else
            print_error "Application is not accessible via port-forward"
            ((FAILED_TESTS++))
        fi

        kill $pf_pid 2>/dev/null || true
    else
        if curl -s -f -o /dev/null "http://$ingress_host:$ingress_port/productpage"; then
            print_success "Application is accessible via LoadBalancer"
        else
            print_error "Application is not accessible via LoadBalancer"
            ((FAILED_TESTS++))
        fi
    fi
}

test_addons() {
    print_status "Testing Istio addons..."
    
    local addons=("kiali" "jaeger" "grafana" "prometheus")
    
    for addon in "${addons[@]}"; do
        if kubectl get service $addon -n $ISTIO_NAMESPACE &> /dev/null; then
            print_success "$addon service exists"
        else
            print_warning "$addon service not found (optional)"
        fi
    done
}

test_mtls() {
    print_status "Testing mTLS configuration..."
    
    # Check if PeerAuthentication policy exists
    if kubectl get peerauthentication default -n $BOOKINFO_NAMESPACE &> /dev/null; then
        print_success "PeerAuthentication policy exists"
    else
        print_warning "PeerAuthentication policy not found (optional)"
    fi
    
    # Test mTLS by checking if communication works
    local productpage_pod=$(kubectl get pod -l app=productpage -n $BOOKINFO_NAMESPACE -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    
    if [ -n "$productpage_pod" ]; then
        if kubectl exec $productpage_pod -n $BOOKINFO_NAMESPACE -c productpage -- curl -s -f -o /dev/null http://details:9080/details/123; then
            print_success "Inter-service communication works (mTLS likely enabled)"
        else
            print_warning "Inter-service communication test failed"
        fi
    else
        print_warning "Could not find productpage pod for mTLS test"
    fi
}

show_summary() {
    echo ""
    echo "🧪 Test Summary"
    echo "==============="
    
    if [ $FAILED_TESTS -eq 0 ]; then
        print_success "All tests passed! Istio demo is working correctly."
        echo ""
        echo "🌐 Access the application:"
        echo "kubectl port-forward -n istio-system svc/istio-ingressgateway 8080:80"
        echo "Then visit: http://localhost:8080/productpage"
        echo ""
        echo "📊 Access observability tools:"
        echo "./access-kiali.sh   - Kiali dashboard"
        echo "./access-jaeger.sh  - Jaeger tracing"
        echo ""
        echo "🚦 Generate traffic:"
        echo "./generate-traffic.sh"
    else
        print_error "$FAILED_TESTS test(s) failed. Please check the deployment."
        exit 1
    fi
}

main() {
    echo "🧪 Running Istio Service Mesh Demo Tests"
    echo "========================================"
    
    test_namespace_exists
    test_istio_components
    test_bookinfo_app
    test_istio_injection
    test_gateway_configuration
    test_application_connectivity
    test_addons
    test_mtls
    
    show_summary
}

# Run main function
main "$@"
