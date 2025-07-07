#!/bin/bash

# 🧪 Manual Lab Testing Script
# 
# This script helps you manually trigger the verification workflows
# for testing purposes before they run automatically.

# Set text colors
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
RED="\033[0;31m"
PURPLE="\033[0;35m"
CYAN="\033[0;36m"
NC="\033[0m" # No Color

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${NC}                                                               ${BLUE}║${NC}"
echo -e "${BLUE}║${NC}  🧪 ${YELLOW}Manual Kubernetes Lab Testing${NC}                        ${BLUE}║${NC}"
echo -e "${BLUE}║${NC}                                                               ${BLUE}║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo

show_help() {
    echo -e "${CYAN}Usage:${NC}"
    echo -e "  $0 ${GREEN}[test-type]${NC}"
    echo
    echo -e "${CYAN}Test Types:${NC}"
    echo -e "  ${GREEN}kind${NC}      - Test Kind cluster setup only"
    echo -e "  ${GREEN}minikube${NC}  - Test Minikube cluster setup only"
    echo -e "  ${GREEN}both${NC}      - Test both setups (default)"
    echo
    echo -e "${CYAN}Examples:${NC}"
    echo -e "  $0           # Test both Kind and Minikube"
    echo -e "  $0 kind      # Test only Kind setup"
    echo -e "  $0 minikube  # Test only Minikube setup"
    echo
    echo -e "${YELLOW}Note:${NC} This script requires GitHub CLI (gh) to be installed and authenticated."
}

check_gh_cli() {
    if ! command -v gh &> /dev/null; then
        echo -e "${RED}❌ Error: GitHub CLI (gh) is not installed${NC}"
        echo -e "💡 Please install GitHub CLI first:"
        echo -e "   ${CYAN}brew install gh${NC} (macOS)"
        echo -e "   ${CYAN}sudo apt install gh${NC} (Ubuntu/Debian)"
        echo -e "   ${CYAN}https://cli.github.com/${NC} (Other platforms)"
        exit 1
    fi
    
    if ! gh auth status &> /dev/null; then
        echo -e "${RED}❌ Error: GitHub CLI is not authenticated${NC}"
        echo -e "💡 Please authenticate with GitHub first:"
        echo -e "   ${CYAN}gh auth login${NC}"
        exit 1
    fi
}

trigger_workflow() {
    local workflow_name=$1
    local test_type=${2:-"both"}
    
    echo -e "${YELLOW}🚀 Triggering $workflow_name workflow...${NC}"
    
    if [ "$workflow_name" = "daily-verification" ]; then
        gh workflow run daily-verification.yml -f test_type="$test_type"
    else
        gh workflow run "$workflow_name.yml"
    fi
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Workflow triggered successfully!${NC}"
        echo -e "📊 View progress at: ${CYAN}https://github.com/$(gh repo view --json owner,name -q '.owner.login + "/" + .name')/actions${NC}"
    else
        echo -e "${RED}❌ Failed to trigger workflow${NC}"
        return 1
    fi
}

# Main script
TEST_TYPE=${1:-"both"}

case $TEST_TYPE in
    help|--help|-h)
        show_help
        exit 0
        ;;
    kind)
        echo -e "${BLUE}🔶 Testing Kind cluster setup only...${NC}"
        ;;
    minikube)
        echo -e "${BLUE}🔷 Testing Minikube cluster setup only...${NC}"
        ;;
    both)
        echo -e "${BLUE}🚀 Testing both Kind and Minikube cluster setups...${NC}"
        ;;
    *)
        echo -e "${RED}❌ Invalid test type: $TEST_TYPE${NC}"
        echo
        show_help
        exit 1
        ;;
esac

# Check prerequisites
check_gh_cli

echo -e "${YELLOW}⚠️  This will trigger GitHub Actions workflows which consume runner minutes.${NC}"
read -p "Continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}⏹️  Operation cancelled${NC}"
    exit 0
fi

# Trigger appropriate workflows
case $TEST_TYPE in
    kind)
        trigger_workflow "verify-kind-cluster"
        ;;
    minikube)
        trigger_workflow "verify-minikube-cluster"
        ;;
    both)
        trigger_workflow "daily-verification" "both"
        ;;
esac

echo
echo -e "${GREEN}🎉 Test workflows have been triggered!${NC}"
echo -e "📱 You'll receive notifications when the workflows complete."
echo -e "📊 Monitor progress in the GitHub Actions tab of your repository."
