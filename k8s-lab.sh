#!/bin/bash
set -euo pipefail

# 🚀 Kubernetes Lab Management Script
# 
# A unified script to manage both Minikube and Kind clusters
# ------------------------------------------------------------------------------

# Set text colors
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
RED="\033[0;31m"
PURPLE="\033[0;35m"
CYAN="\033[0;36m"
NC="\033[0m" # No Color

# Print header
echo -e "${BLUE}"
echo "╔═════════════════════════════════════════════════════════════╗"
echo "║                                                             ║"
echo "║  🚀 ${YELLOW}Kubernetes Development Clusters Management${BLUE}             ║"
echo "║                                                             ║"
echo "╚═════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Functions
show_help() {
    echo -e "${CYAN}Usage:${NC}"
    echo -e "  $0 ${GREEN}command${NC} ${YELLOW}[options]${NC}"
    echo
    echo -e "${CYAN}Commands:${NC}"
    echo -e "  ${GREEN}start${NC} ${YELLOW}<minikube|kind> [profile_name]${NC}  Start a cluster (default profile if not specified)"
    echo -e "  ${GREEN}stop${NC} ${YELLOW}<minikube|kind> [profile_name]${NC}   Stop a cluster (default profile if not specified)"
    echo -e "  ${GREEN}status${NC} ${YELLOW}[minikube|kind]${NC}                Check cluster status (all clusters if type not specified)"
    echo -e "  ${GREEN}deploy-demo${NC} ${YELLOW}<minikube|kind> [profile]${NC} Deploy the basic demo application"
    echo -e "  ${GREEN}deploy-advanced${NC} ${YELLOW}<minikube|kind> [profile] [demo]${NC} Deploy advanced demos"
    echo -e "  ${GREEN}dashboard${NC} ${YELLOW}<minikube|kind> [profile]${NC}   Open the dashboard (minikube) or k9s (kind)"
    echo -e "  ${GREEN}cleanup${NC} ${YELLOW}<minikube|kind> [profile]${NC}     Delete cluster and clean resources"
    echo -e "  ${GREEN}help${NC}                                Display this help message"
    echo
    echo -e "${CYAN}Examples:${NC}"
    echo -e "  $0 ${GREEN}start${NC} ${YELLOW}minikube my-cluster${NC}          Start a minikube cluster named 'my-cluster'"
    echo -e "  $0 ${GREEN}status${NC}                           Show status of all clusters"
    echo -e "  $0 ${GREEN}deploy-demo${NC} ${YELLOW}kind my-kind-cluster${NC}   Deploy demo app to a kind cluster"
    echo -e "  $0 ${GREEN}deploy-advanced${NC} ${YELLOW}minikube default all${NC}   Deploy all advanced demos"
}

check_tool() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${RED}❌ Error: $1 is not installed${NC}"
        echo -e "💡 Please install $1 first. See the lab README for instructions."
        exit 1
    fi
}

check_docker_running() {
    if ! docker info &> /dev/null; then
        echo -e "${RED}❌ Error: Docker is not running. Please start Docker first.${NC}"
        exit 1
    fi
}

validate_script_exists() {
    if [ ! -f "$1" ]; then
        echo -e "${RED}❌ Error: Script not found: $1${NC}"
        echo -e "💡 Make sure you are running this from the repository root directory."
        exit 1
    fi
}

start_cluster() {
    local env_type=$1
    local cluster_name=$2
    
    if [ "$env_type" = "minikube" ]; then
        check_tool minikube
        
        # Set default minikube cluster name if not provided
        if [ -z "$cluster_name" ]; then
            cluster_name="minikube-multinode"
        fi
        
        echo -e "${YELLOW}🚀 Starting Minikube cluster: $cluster_name ${NC}"
        # Check if cluster exists first
        if minikube profile list -o json 2>/dev/null | grep -q "\"Name\":\"$cluster_name\""; then
            echo -e "${YELLOW}✅ Found existing cluster with profile '$cluster_name'${NC}"
            
            # Check status using jq if available, fall back to grep
            if command -v jq &> /dev/null; then
                STATUS=$( (minikube status -p "$cluster_name" -o json 2>/dev/null || true) | jq -r '.Host // "Unknown"')
            else
                STATUS=$(minikube status -p "$cluster_name" -o json 2>/dev/null | grep -o '"Host":"[^"]*"' | cut -d'"' -f4 || echo "Unknown")
            fi
            
            if [ "$STATUS" = "Running" ]; then
                echo -e "${GREEN}✅ Cluster is already running!${NC}"
                minikube status -p "$cluster_name"
                return 0
            else
                echo -e "${YELLOW}🔄 Starting existing cluster with profile '$cluster_name'...${NC}"
                minikube start -p "$cluster_name"
                echo -e "${GREEN}✅ Cluster started successfully!${NC}"
                return 0
            fi
        else
            # Let the setup script handle creating a new cluster
            validate_script_exists "./minikube-lab/setup-minikube.sh"
            ./minikube-lab/setup-minikube.sh "$cluster_name"
        fi
    
    elif [ "$env_type" = "kind" ]; then
        check_tool kind
        check_tool docker
        check_docker_running
        
        # Set default kind cluster name if not provided
        if [ -z "$cluster_name" ]; then
            cluster_name="kind-multi-node"
        fi
        
        echo -e "${YELLOW}🚀 Starting Kind cluster: $cluster_name ${NC}"
        # Check if cluster exists
        if kind get clusters 2>/dev/null | grep -q "^${cluster_name}$"; then
            echo -e "${YELLOW}✅ Found existing cluster named '$cluster_name'!${NC}"
            
            # Check if control-plane container is running
            CONTAINER_RUNNING=$(docker ps -q --filter "name=${cluster_name}-control-plane" --filter "status=running" | wc -l | tr -d ' ')
            
            if [ "$CONTAINER_RUNNING" -gt 0 ]; then
                echo -e "${GREEN}✅ Cluster is already running!${NC}"
                kubectl config use-context "kind-${cluster_name}"
                kubectl cluster-info --context "kind-${cluster_name}"
                return 0
            else
                CONTAINER_EXISTS=$(docker ps -a -q --filter "name=${cluster_name}-control-plane" | wc -l | tr -d ' ')
                if [ "$CONTAINER_EXISTS" -gt 0 ]; then
                    echo -e "${YELLOW}🔄 Existing containers found. Starting them...${NC}"
                    CONTAINERS=$(docker ps -a --filter "name=${cluster_name}-" --format "{{.ID}}")
                    if [ -n "$CONTAINERS" ]; then
                        echo "$CONTAINERS" | xargs docker start
                    fi
                    echo -e "${GREEN}✅ Containers started! Waiting for cluster to be ready...${NC}"
                    sleep 5  # Give the cluster a moment to initialize
                    kubectl config use-context "kind-${cluster_name}"
                    kubectl cluster-info --context "kind-${cluster_name}"
                    return 0
                fi
            fi
        fi
        
        # Let the setup script handle creation or recreation
        validate_script_exists "./kind-lab/setup-kind.sh"
        ./kind-lab/setup-kind.sh "$cluster_name"
    
    else
        echo -e "${RED}❌ Error: Please specify 'minikube' or 'kind' as the environment type${NC}"
        exit 1
    fi
}

stop_cluster() {
    local env_type=$1
    local cluster_name=$2
    
    if [ "$env_type" = "minikube" ]; then
        check_tool minikube
        
        # Set default minikube cluster name if not provided
        if [ -z "$cluster_name" ]; then
            cluster_name="minikube-multinode"
        fi
        
        echo -e "${YELLOW}🛑 Stopping Minikube cluster: $cluster_name ${NC}"
        minikube stop -p "$cluster_name"
    
    elif [ "$env_type" = "kind" ]; then
        check_tool kind
        
        # Set default kind cluster name if not provided
        if [ -z "$cluster_name" ]; then
            cluster_name="kind-multi-node"
        fi
        
        echo -e "${RED}❗ Kind doesn't have a stop feature. Use 'cleanup' to remove the cluster.${NC}"
        echo -e "${YELLOW}💡 If you want to free resources, you can stop the Docker containers manually.${NC}"
    
    else
        echo -e "${RED}❌ Error: Please specify 'minikube' or 'kind' as the environment type${NC}"
        exit 1
    fi
}

check_status() {
    local env_type=$1
    
    check_tool kubectl
    
    echo -e "${CYAN}📊 Checking Kubernetes Cluster Status:${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    if [ -z "$env_type" ] || [ "$env_type" = "minikube" ]; then
        if command -v minikube &> /dev/null; then
            echo -e "${YELLOW}🔷 Minikube Clusters:${NC}"
            minikube profile list 2>/dev/null || echo -e "${YELLOW}  No Minikube profiles found${NC}"
            echo
        else
            echo -e "${YELLOW}🔷 Minikube: not installed${NC}"
            echo
        fi
    fi
    
    if [ -z "$env_type" ] || [ "$env_type" = "kind" ]; then
        if command -v kind &> /dev/null; then
            echo -e "${YELLOW}🔶 Kind Clusters:${NC}"
            kind get clusters 2>/dev/null || echo -e "${YELLOW}  No Kind clusters found${NC}"
            echo
        else
            echo -e "${YELLOW}🔶 Kind: not installed${NC}"
            echo
        fi
    fi
    
    echo -e "${CYAN}📊 Kubernetes Contexts:${NC}"
    kubectl config get-contexts 2>/dev/null || echo -e "${YELLOW}  No contexts configured${NC}"
    echo
    
    echo -e "${CYAN}📊 Current Context:${NC}"
    kubectl config current-context 2>/dev/null || echo -e "${YELLOW}  No current context set${NC}"
}

deploy_demo() {
    local env_type=$1
    local cluster_name=$2
    
    if [ -z "$env_type" ]; then
        echo -e "${RED}❌ Error: Please specify 'minikube' or 'kind' as the environment type${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}🚀 Deploying demo application to $env_type cluster: $cluster_name ${NC}"
    validate_script_exists "./demo-app/deploy-demo.sh"
    # Change to the demo-app directory before running the deploy script
    cd demo-app && ./deploy-demo.sh "$env_type" "$cluster_name"
    cd ..
}

deploy_advanced() {
    local env_type=$1
    local cluster_name=$2
    local demo_type=${3:-"all"}
    
    if [ -z "$env_type" ]; then
        echo -e "${RED}❌ Error: Please specify 'minikube' or 'kind' as the environment type${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}🚀 Deploying advanced demo applications to $env_type cluster: $cluster_name ${NC}"
    validate_script_exists "./demo-app/advanced-demos/deploy-advanced-demos.sh"
    # Change to the advanced-demos directory before running the deploy script
    cd demo-app/advanced-demos && ./deploy-advanced-demos.sh "$env_type" "$cluster_name" "$demo_type"
    cd ../..
}

open_dashboard() {
    local env_type=$1
    local cluster_name=$2
    
    if [ "$env_type" = "minikube" ]; then
        check_tool minikube
        
        # Set default minikube cluster name if not provided
        if [ -z "$cluster_name" ]; then
            cluster_name="minikube-multinode"
        fi
        
        echo -e "${GREEN}📊 Opening Kubernetes Dashboard for Minikube: $cluster_name ${NC}"
        minikube dashboard -p "$cluster_name"
        
    elif [ "$env_type" = "kind" ]; then
        # Check if k9s is installed
        if ! command -v k9s &> /dev/null; then
            echo -e "${YELLOW}⚠️ K9s tool is not installed${NC}"
            echo -e "${CYAN}💡 For better Kind cluster management, we recommend installing K9s:${NC}"
            echo -e "   brew install k9s (macOS)"
            echo -e "   snap install k9s (Linux with snap)"
            echo -e "${CYAN}Using kubectl instead...${NC}"
            
            # Set default kind cluster name if not provided
            if [ -z "$cluster_name" ]; then
                cluster_name="kind-multi-node"
            fi
            
            # Make sure we're using the correct Kind context
            kubectl config use-context "kind-$cluster_name"
            
            # Show some helpful output instead
            echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${CYAN}📊 Showing Kind Cluster Info:${NC}"
            
            echo -e "${YELLOW}📋 Nodes:${NC}"
            kubectl get nodes -o wide
            
            echo -e "${YELLOW}📋 Pods:${NC}"
            kubectl get pods -A
        else
            echo -e "${GREEN}📊 Opening K9s for Kind cluster management${NC}"
            
            # Set default kind cluster name if not provided
            if [ -z "$cluster_name" ]; then
                cluster_name="kind-multi-node"
            fi
            
            # Make sure we're using the correct Kind context
            kubectl config use-context "kind-$cluster_name"
            
            # Launch k9s
            k9s
        fi
    
    else
        echo -e "${RED}❌ Error: Please specify 'minikube' or 'kind' as the environment type${NC}"
        exit 1
    fi
}

cleanup_cluster() {
    local env_type=$1
    local cluster_name=$2
    
    if [ "$env_type" = "minikube" ]; then
        check_tool minikube
        
        # Set default minikube cluster name if not provided
        if [ -z "$cluster_name" ]; then
            cluster_name="minikube-multinode"
        fi
        
        echo -e "${RED}⚠️ Cleaning up Minikube cluster: $cluster_name ${NC}"
        echo -e "${YELLOW}This will delete the cluster and all related resources.${NC}"
        read -rp "Are you sure you want to proceed? (y/n): " confirm
        if [[ $confirm =~ ^[Yy](es)?$ ]]; then
            minikube delete -p "$cluster_name"
            echo -e "${GREEN}✅ Cluster $cluster_name has been deleted${NC}"
        else
            echo -e "${YELLOW}⚠️ Cleanup cancelled${NC}"
        fi
        
    elif [ "$env_type" = "kind" ]; then
        check_tool kind
        
        # Set default kind cluster name if not provided
        if [ -z "$cluster_name" ]; then
            cluster_name="kind-multi-node"
        fi
        
        echo -e "${RED}⚠️ Cleaning up Kind cluster: $cluster_name ${NC}"
        echo -e "${YELLOW}This will delete the cluster and all related resources.${NC}"
        read -rp "Are you sure you want to proceed? (y/n): " confirm
        if [[ $confirm =~ ^[Yy](es)?$ ]]; then
            kind delete cluster --name "$cluster_name"
            echo -e "${GREEN}✅ Cluster $cluster_name has been deleted${NC}"
        else
            echo -e "${YELLOW}⚠️ Cleanup cancelled${NC}"
        fi
        
    else
        echo -e "${RED}❌ Error: Please specify 'minikube' or 'kind' as the environment type${NC}"
        exit 1
    fi
}

# Main script execution
case "${1:-}" in
    start)
        start_cluster "${2:-}" "${3:-}"
        ;;
    stop)
        stop_cluster "${2:-}" "${3:-}"
        ;;
    status)
        check_status "${2:-}"
        ;;
    deploy-demo)
        deploy_demo "${2:-}" "${3:-}"
        ;;
    deploy-advanced)
        deploy_advanced "${2:-}" "${3:-}" "${4:-}"
        ;;
    dashboard)
        open_dashboard "${2:-}" "${3:-}"
        ;;
    cleanup)
        cleanup_cluster "${2:-}" "${3:-}"
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo -e "${RED}❌ Error: Unknown command '${1:-}'${NC}"
        show_help
        exit 1
        ;;
esac
