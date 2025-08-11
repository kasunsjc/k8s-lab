#!/bin/bash

# 🌐 Istio Service Mesh Demo Deployment Script
#
# This script deploys Istio using Helm and sets up sample applications

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ISTIO_VERSION="1.22.3"
ISTIO_NAMESPACE="istio-system"
BOOKINFO_NAMESPACE="default"

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

check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed. Please install kubectl first."
        exit 1
    fi
    
    # Check if helm is available
    if ! command -v helm &> /dev/null; then
        print_error "Helm is not installed. Please install Helm first."
        exit 1
    fi
    
    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

add_istio_helm_repo() {
    print_status "Adding Istio Helm repository..."
    helm repo add istio https://istio-release.storage.googleapis.com/charts
    helm repo update
    print_success "Istio Helm repository added"
}

create_namespaces() {
    print_status "Creating namespaces..."
    kubectl create namespace $ISTIO_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    kubectl label namespace $BOOKINFO_NAMESPACE istio-injection=enabled --overwrite
    print_success "Namespaces created and labeled"
}

install_istio_base() {
    print_status "Installing Istio base components..."
    helm upgrade --install istio-base istio/base \
        -n $ISTIO_NAMESPACE \
        --version $ISTIO_VERSION \
        --wait
    print_success "Istio base components installed"
}

install_istio_discovery() {
    print_status "Installing Istio discovery (istiod)..."
    helm upgrade --install istiod istio/istiod \
        -n $ISTIO_NAMESPACE \
        --version $ISTIO_VERSION \
        --wait \
        --timeout 600s
    print_success "Istio discovery installed"
}

install_istio_gateway() {
    print_status "Installing Istio Ingress Gateway..."
    helm upgrade --install istio-ingressgateway istio/gateway \
        -n $ISTIO_NAMESPACE \
        --version $ISTIO_VERSION \
        --wait \
        --set service.type=LoadBalancer \
        --set service.ports[0].port=80 \
        --set service.ports[0].name=http2 \
        --set service.ports[1].port=443 \
        --set service.ports[1].name=https
    print_success "Istio Ingress Gateway installed"
}

wait_for_istio() {
    print_status "Waiting for Istio components to be ready..."
    kubectl wait --for=condition=available --timeout=600s deployment/istiod -n $ISTIO_NAMESPACE
    print_success "Istio components are ready"
}

deploy_addons() {
    print_status "Deploying Istio addons (Kiali, Jaeger, Grafana, Prometheus)..."
    
    # Create addons directory if it doesn't exist
    mkdir -p ./addons
    
    # Download and apply Istio addons
    curl -L https://raw.githubusercontent.com/istio/istio/release-${ISTIO_VERSION}/samples/addons/prometheus.yaml -o ./addons/prometheus.yaml
    curl -L https://raw.githubusercontent.com/istio/istio/release-${ISTIO_VERSION}/samples/addons/grafana.yaml -o ./addons/grafana.yaml
    curl -L https://raw.githubusercontent.com/istio/istio/release-${ISTIO_VERSION}/samples/addons/jaeger.yaml -o ./addons/jaeger.yaml
    curl -L https://raw.githubusercontent.com/istio/istio/release-${ISTIO_VERSION}/samples/addons/kiali.yaml -o ./addons/kiali.yaml
    
    kubectl apply -f ./addons/
    
    print_success "Istio addons deployed"
}

deploy_bookinfo_app() {
    print_status "Deploying BookInfo sample application..."
    
    # Apply BookInfo application
    kubectl apply -f bookinfo-app.yaml
    
    # Wait for deployments to be ready
    kubectl wait --for=condition=available --timeout=300s deployment/productpage-v1
    kubectl wait --for=condition=available --timeout=300s deployment/details-v1
    kubectl wait --for=condition=available --timeout=300s deployment/reviews-v1
    kubectl wait --for=condition=available --timeout=300s deployment/reviews-v2
    kubectl wait --for=condition=available --timeout=300s deployment/reviews-v3
    kubectl wait --for=condition=available --timeout=300s deployment/ratings-v1
    
    print_success "BookInfo application deployed"
}

deploy_gateway_and_virtualservice() {
    print_status "Deploying Gateway and VirtualService..."
    kubectl apply -f istio-gateway.yaml
    kubectl apply -f traffic-management.yaml
    print_success "Gateway and VirtualService deployed"
}

deploy_httpbin() {
    print_status "Deploying HTTPBin service for testing..."
    kubectl apply -f httpbin.yaml
    print_success "HTTPBin service deployed"
}

show_access_info() {
    print_status "Getting access information..."
    
    # Get ingress gateway service info
    INGRESS_HOST=$(kubectl get svc istio-ingressgateway -n $ISTIO_NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    INGRESS_PORT=$(kubectl get svc istio-ingressgateway -n $ISTIO_NAMESPACE -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')
    
    if [ -z "$INGRESS_HOST" ]; then
        INGRESS_HOST=$(kubectl get svc istio-ingressgateway -n $ISTIO_NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
    fi
    
    if [ -z "$INGRESS_HOST" ]; then
        INGRESS_HOST="localhost"
        print_warning "LoadBalancer IP not available, using port-forward for access"
        echo ""
        echo "🌐 Access the BookInfo application:"
        echo "kubectl port-forward -n $ISTIO_NAMESPACE svc/istio-ingressgateway 8080:80"
        echo "Then visit: http://localhost:8080/productpage"
    else
        echo ""
        echo "🌐 BookInfo application URL: http://$INGRESS_HOST:$INGRESS_PORT/productpage"
    fi
    
    echo ""
    echo "📊 Observability Tools:"
    echo "Kiali:      kubectl port-forward -n $ISTIO_NAMESPACE svc/kiali 20001:20001"
    echo "Jaeger:     kubectl port-forward -n $ISTIO_NAMESPACE svc/jaeger 16686:16686"
    echo "Grafana:    kubectl port-forward -n $ISTIO_NAMESPACE svc/grafana 3000:3000"
    echo "Prometheus: kubectl port-forward -n $ISTIO_NAMESPACE svc/prometheus 9090:9090"
    echo ""
    echo "🔧 Quick access scripts:"
    echo "./access-kiali.sh   - Open Kiali dashboard"
    echo "./access-jaeger.sh  - Open Jaeger tracing"
    echo "./generate-traffic.sh - Generate test traffic"
}

main() {
    echo "🚀 Starting Istio Service Mesh Demo Deployment"
    echo "==============================================="
    
    check_prerequisites
    add_istio_helm_repo
    create_namespaces
    install_istio_base
    install_istio_discovery
    install_istio_gateway
    wait_for_istio
    deploy_addons
    
    # Wait a bit for addons to start
    sleep 30
    
    deploy_bookinfo_app
    deploy_gateway_and_virtualservice
    deploy_httpbin
    
    echo ""
    print_success "Istio Service Mesh Demo deployment completed successfully!"
    echo ""
    
    show_access_info
}

# Run main function
main "$@"
