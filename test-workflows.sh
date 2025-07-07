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
    echo -e "  $0 ${GREEN}[test-type] [branch]${NC}"
    echo
    echo -e "${CYAN}Test Types:${NC}"
    echo -e "  ${GREEN}kind${NC}      - Test Kind cluster setup only"
    echo -e "  ${GREEN}minikube${NC}  - Test Minikube cluster setup only"
    echo -e "  ${GREEN}both${NC}      - Test both setups (default)"
    echo
    echo -e "${CYAN}Branch:${NC}"
    echo -e "  ${GREEN}[branch]${NC}  - Branch to run workflow on (default: current branch)"
    echo
    echo -e "${CYAN}Examples:${NC}"
    echo -e "  $0                           # Test both on current branch"
    echo -e "  $0 kind                      # Test only Kind on current branch"
    echo -e "  $0 minikube main             # Test only Minikube on main branch"
    echo -e "  $0 both feature/my-branch    # Test both on specific branch"
    echo
    echo -e "${YELLOW}Note:${NC} This script requires GitHub CLI (gh) to be installed and authenticated."
    echo -e "${YELLOW}Note:${NC} Workflows must exist on the specified branch to be triggered."
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

get_current_branch() {
    git branch --show-current 2>/dev/null || echo "main"
}

check_workflow_exists() {
    local workflow_file=$1
    local branch=$2
    
    echo -e "${CYAN}🔍 Checking if workflow exists on branch '$branch'...${NC}"
    
    # Check if workflow file exists on the specified branch
    if git show "$branch:.github/workflows/$workflow_file" &> /dev/null; then
        echo -e "${GREEN}✅ Workflow '$workflow_file' found on branch '$branch'${NC}"
        return 0
    else
        echo -e "${RED}❌ Workflow '$workflow_file' not found on branch '$branch'${NC}"
        echo -e "💡 Make sure the workflow file exists and is committed to the branch"
        return 1
    fi
}

trigger_workflow() {
    local workflow_name=$1
    local test_type=${2:-"both"}
    local branch=${3:-$(get_current_branch)}
    
    local workflow_file="$workflow_name.yml"
    
    # Check if workflow exists on the branch
    if ! check_workflow_exists "$workflow_file" "$branch"; then
        return 1
    fi
    
    echo -e "${YELLOW}🚀 Triggering $workflow_name workflow on branch '$branch'...${NC}"
    
    if [ "$workflow_name" = "daily-verification" ]; then
        gh workflow run daily-verification.yml --ref "$branch" -f test_type="$test_type"
    else
        gh workflow run "$workflow_name.yml" --ref "$branch"
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
BRANCH=${2:-$(get_current_branch)}

# Display current settings
echo -e "${CYAN}🔧 Configuration:${NC}"
echo -e "  Test Type: ${GREEN}$TEST_TYPE${NC}"
echo -e "  Branch: ${GREEN}$BRANCH${NC}"
echo

case $TEST_TYPE in
    help|--help|-h)
        show_help
        exit 0
        ;;
    kind)
        echo -e "${BLUE}🔶 Testing Kind cluster setup only on branch '$BRANCH'...${NC}"
        ;;
    minikube)
        echo -e "${BLUE}🔷 Testing Minikube cluster setup only on branch '$BRANCH'...${NC}"
        ;;
    both)
        echo -e "${BLUE}🚀 Testing both Kind and Minikube cluster setups on branch '$BRANCH'...${NC}"
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

# Verify git repository
if ! git rev-parse --git-dir &> /dev/null; then
    echo -e "${RED}❌ Error: Not in a git repository${NC}"
    exit 1
fi

# Check if branch exists
if ! git show-ref --verify --quiet "refs/heads/$BRANCH" && ! git show-ref --verify --quiet "refs/remotes/origin/$BRANCH"; then
    echo -e "${RED}❌ Error: Branch '$BRANCH' does not exist${NC}"
    echo -e "💡 Available branches:"
    git branch -a | sed 's/^/   /'
    exit 1
fi

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
        trigger_workflow "verify-kind-cluster" "" "$BRANCH"
        ;;
    minikube)
        trigger_workflow "verify-minikube-cluster" "" "$BRANCH"
        ;;
    both)
        trigger_workflow "daily-verification" "both" "$BRANCH"
        ;;
esac

echo
echo -e "${GREEN}🎉 Test workflows have been triggered!${NC}"
echo -e "📱 You'll receive notifications when the workflows complete."
echo -e "📊 Monitor progress in the GitHub Actions tab of your repository."
