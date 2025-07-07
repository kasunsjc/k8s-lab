#!/usr/bin/env bash

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

merge_to_main() {
    local current_branch=$(get_current_branch)
    
    echo -e "${CYAN}🔄 Merging workflows to main branch...${NC}"
    echo -e "${YELLOW}Current branch: $current_branch${NC}"
    
    # Check if we have uncommitted changes
    if ! git diff-index --quiet HEAD --; then
        echo -e "${YELLOW}⚠️  You have uncommitted changes. Committing them first...${NC}"
        git add .github/workflows/ test-workflows.sh
        read -p "Enter commit message (or press Enter for default): " commit_msg
        if [ -z "$commit_msg" ]; then
            commit_msg="Update workflows and test script"
        fi
        git commit -m "$commit_msg"
    fi
    
    # Push current branch
    echo -e "${CYAN}📤 Pushing current branch...${NC}"
    git push origin "$current_branch"
    
    # Switch to main and merge
    echo -e "${CYAN}🔄 Switching to main branch...${NC}"
    git checkout main
    git pull origin main
    
    echo -e "${CYAN}🔗 Merging $current_branch into main...${NC}"
    git merge "$current_branch"
    
    echo -e "${CYAN}📤 Pushing to main...${NC}"
    git push origin main
    
    echo -e "${GREEN}✅ Successfully merged workflows to main!${NC}"
    echo -e "${CYAN}💡 You can now run workflows using:${NC}"
    echo -e "   ${GREEN}./test-workflows.sh both main${NC}"
    
    # Switch back to feature branch
    echo -e "${CYAN}🔄 Switching back to $current_branch...${NC}"
    git checkout "$current_branch"
}

show_help() {
    echo -e "${CYAN}Usage:${NC}"
    echo -e "  $0 ${GREEN}[test-type] [branch]${NC}"
    echo -e "  $0 ${GREEN}merge${NC}                              # Merge current branch to main"
    echo
    echo -e "${CYAN}Test Types:${NC}"
    echo -e "  ${GREEN}kind${NC}      - Test Kind cluster setup only"
    echo -e "  ${GREEN}minikube${NC}  - Test Minikube cluster setup only"
    echo -e "  ${GREEN}both${NC}      - Test both setups (default)"
    echo -e "  ${GREEN}merge${NC}     - Merge current branch workflows to main"
    echo
    echo -e "${CYAN}Branch:${NC}"
    echo -e "  ${GREEN}[branch]${NC}  - Branch to run workflow on (default: current branch)"
    echo
    echo -e "${CYAN}Examples:${NC}"
    echo -e "  $0                           # Test both on current branch"
    echo -e "  $0 kind                      # Test only Kind on current branch"
    echo -e "  $0 minikube main             # Test only Minikube on main branch"
    echo -e "  $0 both feature/my-branch    # Test both on specific branch"
    echo -e "  $0 merge                     # Merge workflows to main and test there"
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

check_workflow_api_availability() {
    local workflow_file=$1
    
    echo -e "${CYAN}🔍 Checking if workflow is available via GitHub API...${NC}"
    
    # Retrieve the repository context
    local repo_context
    repo_context=$(gh repo view --json owner,name -q '.owner.login+"/"+.name')
    
    # Try to get workflow info via GitHub API
    if gh api "repos/$repo_context/actions/workflows/$workflow_file" &> /dev/null; then
        echo -e "${GREEN}✅ Workflow is available via GitHub API${NC}"
        return 0
    else
        echo -e "${RED}❌ Workflow not available via GitHub API${NC}"
        echo -e "${YELLOW}💡 This usually means the workflow doesn't exist on the default branch (main/master)${NC}"
        return 1
    fi
}

check_workflow_exists() {
    local workflow_file=$1
    local branch=$2
    
    echo -e "${CYAN}🔍 Checking if workflow exists on branch '$branch'...${NC}"
    
    # Check if workflow file exists on the specified branch
    if git show "$branch:.github/workflows/$workflow_file" &> /dev/null; then
        echo -e "${GREEN}✅ Workflow '$workflow_file' found on branch '$branch'${NC}"
        
        # Additional check: workflows are only triggerable via API when on default branch
        if [ "$branch" != "main" ] && [ "$branch" != "master" ]; then
            echo -e "${YELLOW}⚠️  Warning: Workflows can only be triggered via GitHub API when they exist on the default branch (main/master)${NC}"
            echo -e "${YELLOW}   Current branch: $branch${NC}"
            echo -e "${CYAN}💡 To test workflows on feature branches, you have two options:${NC}"
            echo -e "   1. Merge/push the workflows to the main branch first"
            echo -e "   2. Create a Pull Request and the workflows will run automatically"
            echo -e "   3. Push the branch and manually trigger via GitHub web interface"
            echo
            read -p "Do you want to continue anyway? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo -e "${YELLOW}⏹️  Operation cancelled${NC}"
                exit 0
            fi
        fi
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
    
    # Check if workflow is available via GitHub API
    if ! check_workflow_api_availability "$workflow_file"; then
        echo -e "${RED}❌ Cannot trigger workflow: Not available via GitHub API${NC}"
        echo
        echo -e "${CYAN}🚀 Alternative options:${NC}"
        echo -e "   1. Merge this branch to main to make workflows available"
        echo -e "   2. Create a Pull Request - workflows will run automatically"
        echo -e "   3. Go to GitHub web interface → Actions → Select workflow → Run workflow"
        echo
        return 1
    fi
    
    echo -e "${YELLOW}🚀 Triggering $workflow_name workflow on branch '$branch'...${NC}"
    
    if [ "$workflow_name" = "daily-verification" ]; then
        if gh workflow run daily-verification.yml --ref "$branch" -f test_type="$test_type"; then
            echo -e "${GREEN}✅ Workflow triggered successfully!${NC}"
            echo -e "📊 View progress at: ${CYAN}https://github.com/$(gh repo view --json owner,name -q '.owner.login + "/" + .name')/actions${NC}"
        else
            echo -e "${RED}❌ Failed to trigger workflow${NC}"
            return 1
        fi
    else
        if gh workflow run "$workflow_name.yml" --ref "$branch"; then
            echo -e "${GREEN}✅ Workflow triggered successfully!${NC}"
            echo -e "📊 View progress at: ${CYAN}https://github.com/$(gh repo view --json owner,name -q '.owner.login + "/" + .name')/actions${NC}"
        else
            echo -e "${RED}❌ Failed to trigger workflow${NC}"
            return 1
        fi
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

# Special handling for help and merge
case $TEST_TYPE in
    help|--help|-h)
        show_help
        exit 0
        ;;
    merge)
        merge_to_main
        exit 0
        ;;
esac

# Check if we're trying to run on a feature branch
if [ "$BRANCH" != "main" ] && [ "$BRANCH" != "master" ]; then
    echo -e "${YELLOW}⚠️  You're trying to run workflows on a feature branch: $BRANCH${NC}"
    echo -e "${YELLOW}   GitHub Actions workflows are only triggerable via API when they exist on the default branch.${NC}"
    echo
    echo -e "${CYAN}🚀 Quick solution - Merge to main:${NC}"
    echo -e "   ${GREEN}git checkout main && git merge $BRANCH && git push origin main${NC}"
    echo
    echo -e "${CYAN}📋 Alternative options:${NC}"
    echo -e "   1. Create a Pull Request (workflows will run automatically)"
    echo -e "   2. Use GitHub web interface to trigger workflows manually"
    echo -e "   3. Continue anyway (will show detailed error messages)"
    echo
    read -p "Do you want to continue with the current branch anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}⏹️  Operation cancelled${NC}"
        echo -e "${CYAN}💡 Run the merge command above, then try again!${NC}"
        exit 0
    fi
fi

case $TEST_TYPE in
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
        echo -e "${CYAN}💡 Valid types: kind, minikube, both, merge, help${NC}"
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
