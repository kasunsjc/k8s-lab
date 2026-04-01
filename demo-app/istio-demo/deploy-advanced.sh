#!/bin/bash

# 🚀 Deploy Advanced Istio Demos Script

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

deploy_security_policies() {
    print_status "Deploying security policies..."
    kubectl apply -f security-policies.yaml
    print_success "Security policies deployed"
}

deploy_fault_injection() {
    print_status "Deploying fault injection examples..."
    kubectl apply -f advanced-examples/fault-injection.yaml
    print_success "Fault injection configured"
    
    echo ""
    echo "🧪 Test fault injection:"
    echo "curl -H 'end-user: jason' http://localhost:8080/productpage"
    echo "This should show delays and errors for user 'jason'"
}

deploy_canary() {
    print_status "Deploying canary deployment (10% traffic to v2)..."
    kubectl apply -f advanced-examples/canary-10-percent.yaml
    print_success "Canary deployment configured"
    
    echo ""
    echo "🚦 Traffic split: 90% v1, 10% v2"
    echo "Generate traffic to see the split in action:"
    echo "./generate-traffic.sh"
}

show_menu() {
    echo ""
    echo "🎯 Advanced Istio Demo Options"
    echo "=============================="
    echo "1. Deploy Security Policies (mTLS, Authorization)"
    echo "2. Deploy Fault Injection Examples"
    echo "3. Deploy Canary Deployment (10% traffic split)"
    echo "4. Deploy All Advanced Features"
    echo "5. Exit"
    echo ""
}

main() {
    echo "🚀 Advanced Istio Features Deployment"
    echo "====================================="
    
    # Check if basic Istio is deployed
    if ! kubectl get namespace istio-system &> /dev/null; then
        echo "❌ Istio is not deployed. Please run ./deploy-istio.sh first."
        exit 1
    fi
    
    if ! kubectl get deployment productpage-v1 &> /dev/null; then
        echo "❌ BookInfo application is not deployed. Please run ./deploy-istio.sh first."
        exit 1
    fi
    
    while true; do
        show_menu
        read -p "Choose an option (1-5): " choice
        
        case $choice in
            1)
                deploy_security_policies
                ;;
            2)
                deploy_fault_injection
                ;;
            3)
                deploy_canary
                ;;
            4)
                deploy_security_policies
                deploy_fault_injection
                deploy_canary
                print_success "All advanced features deployed!"
                ;;
            5)
                echo "Goodbye!"
                exit 0
                ;;
            *)
                print_warning "Invalid option. Please choose 1-5."
                ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}

# Run main function
main "$@"
