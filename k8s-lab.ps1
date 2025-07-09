param(
    [Parameter(Position=0)]
    [string]$Command = '',
    
    [Parameter(Position=1)]
    [string]$Environment = '',
    
    [Parameter(Position=2)]
    [string]$ClusterName = '',
    
    [Parameter(Position=3)]
    [string]$DemoType = 'all'
)

# Check if Command is provided
if ([string]::IsNullOrEmpty($Command)) {
    Write-Host "ERROR: Command is required" -ForegroundColor Red
    Write-Host "Usage: .\k8s-lab.ps1 <command> [options]" -ForegroundColor Yellow
    Write-Host "Run '.\k8s-lab.ps1 help' for more information" -ForegroundColor Yellow
    exit 1
}

Write-Host "Script started with command: $Command" -ForegroundColor Magenta

# Print header
function Show-Header {
    Write-Host "================================================================" -ForegroundColor Blue
    Write-Host "  [*] Kubernetes Development Clusters Management" -ForegroundColor Yellow
    Write-Host "================================================================" -ForegroundColor Blue
    Write-Host ""
}

function Show-Help {
    Write-Host "Usage:" -ForegroundColor Cyan
    Write-Host "  .\k8s-lab.ps1 command [options]" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Commands:" -ForegroundColor Cyan
    Write-Host "  start <minikube|kind> [profile_name]  - Start a cluster" -ForegroundColor Green
    Write-Host "  stop <minikube|kind> [profile_name]   - Stop a cluster" -ForegroundColor Green
    Write-Host "  status [minikube|kind]                - Check cluster status" -ForegroundColor Green
    Write-Host "  deploy-demo <minikube|kind> [profile] - Deploy demo application" -ForegroundColor Green
    Write-Host "  deploy-advanced <minikube|kind> [profile] [demo] - Deploy advanced demos" -ForegroundColor Green
    Write-Host "  dashboard <minikube|kind> [profile]   - Open dashboard" -ForegroundColor Green
    Write-Host "  cleanup <minikube|kind> [profile]     - Delete cluster" -ForegroundColor Green
    Write-Host "  help                                  - Show this help" -ForegroundColor Green
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Cyan
    Write-Host "  .\k8s-lab.ps1 start minikube my-cluster" -ForegroundColor Yellow
    Write-Host "  .\k8s-lab.ps1 status" -ForegroundColor Yellow
    Write-Host "  .\k8s-lab.ps1 deploy-demo kind my-kind-cluster" -ForegroundColor Yellow
}

function Test-Tool {
    param([string]$ToolName)
    
    if (-not (Get-Command $ToolName -ErrorAction SilentlyContinue)) {
        Write-Host "ERROR: $ToolName is not installed" -ForegroundColor Red
        Write-Host "Please install $ToolName first. See the lab README for instructions." -ForegroundColor Yellow
        exit 1
    }
}

function Start-Cluster {
    param(
        [string]$EnvType,
        [string]$ClusterName
    )
    
    if ([string]::IsNullOrEmpty($EnvType)) {
        Write-Host "ERROR: Please specify 'minikube' or 'kind' as the environment type" -ForegroundColor Red
        exit 1
    }
    
    if ($EnvType -eq 'minikube') {
        Test-Tool 'minikube'
        
        # Set default minikube cluster name if not provided
        if ([string]::IsNullOrEmpty($ClusterName)) {
            $ClusterName = 'minikube-multi-node'
        }
        
        Write-Host "[*] Starting Minikube cluster: $ClusterName" -ForegroundColor Yellow
        
        # Check if cluster exists first
        try {
            $profiles = minikube profile list -o json 2>$null | ConvertFrom-Json
            $existingProfile = $profiles.valid | Where-Object { $_.Name -eq $ClusterName }
            
            if ($existingProfile) {
                Write-Host "Found existing cluster with profile '$ClusterName'" -ForegroundColor Yellow
                
                # Check status
                try {
                    $status = minikube status -p $ClusterName -o json 2>$null | ConvertFrom-Json
                    if ($status.Host -eq 'Running') {
                        Write-Host "Cluster is already running!" -ForegroundColor Green
                        minikube status -p $ClusterName
                        return
                    } else {
                        Write-Host "Starting existing cluster with profile '$ClusterName'..." -ForegroundColor Yellow
                        minikube start -p $ClusterName --cpus=2 --memory=2g --extra-config=kubelet.cgroup-driver=systemd --extra-config=kubelet.housekeeping-interval=10s
                        Write-Host "Cluster started successfully!" -ForegroundColor Green
                        return
                    }
                } catch {
                    Write-Host "Starting existing cluster with profile '$ClusterName'..." -ForegroundColor Yellow
                    minikube start -p $ClusterName --cpus=2 --memory=2g --extra-config=kubelet.cgroup-driver=systemd --extra-config=kubelet.housekeeping-interval=10s
                    Write-Host "Cluster started successfully!" -ForegroundColor Green
                    return
                }
            } else {
                # Let the setup script handle creating a new cluster
                if (Test-Path ".\minikube-lab\setup-minikube.ps1") {
                    & ".\minikube-lab\setup-minikube.ps1" $ClusterName
                } else {
                    Write-Host "ERROR: setup-minikube.ps1 not found" -ForegroundColor Red
                    Write-Host "Please run this script from the k8s-lab directory" -ForegroundColor Yellow
                }
            }
        } catch {
            # Let the setup script handle creating a new cluster
            if (Test-Path ".\minikube-lab\setup-minikube.ps1") {
                & ".\minikube-lab\setup-minikube.ps1" $ClusterName
            } else {
                Write-Host "ERROR: setup-minikube.ps1 not found" -ForegroundColor Red
                Write-Host "Please run this script from the k8s-lab directory" -ForegroundColor Yellow
            }
        }
    }
    elseif ($EnvType -eq 'kind') {
        Test-Tool 'kind'
        Test-Tool 'docker'
        
        # Set default kind cluster name if not provided
        if ([string]::IsNullOrEmpty($ClusterName)) {
            $ClusterName = 'kind-multi-node'
        }
        
        Write-Host "[*] Starting Kind cluster: $ClusterName" -ForegroundColor Yellow
        
        # Check if cluster exists
        try {
            $clusters = kind get clusters 2>$null
            if ($clusters -contains $ClusterName) {
                Write-Host "Found existing cluster named '$ClusterName'!" -ForegroundColor Yellow
                
                # Check if control-plane container is running
                $runningContainers = docker ps -q --filter "name=$ClusterName-control-plane" --filter "status=running"
                
                if ($runningContainers) {
                    Write-Host "Cluster is already running!" -ForegroundColor Green
                    kubectl config use-context "kind-$ClusterName"
                    kubectl cluster-info --context "kind-$ClusterName"
                    return
                } else {
                    $existingContainers = docker ps -a -q --filter "name=$ClusterName-control-plane"
                    if ($existingContainers) {
                        Write-Host "Existing containers found. Starting them..." -ForegroundColor Yellow
                        $allContainers = docker ps -a --filter "name=$ClusterName-" --format "{{.ID}}"
                        $allContainers | ForEach-Object { docker start $_ }
                        Write-Host "Containers started! Waiting for cluster to be ready..." -ForegroundColor Green
                        Start-Sleep -Seconds 5
                        kubectl config use-context "kind-$ClusterName"
                        kubectl cluster-info --context "kind-$ClusterName"
                        return
                    }
                }
            }
        } catch {
            # Continue to create new cluster
        }
        
        # Let the setup script handle creation or recreation
        if (Test-Path ".\kind-lab\setup-kind.ps1") {
            & ".\kind-lab\setup-kind.ps1" $ClusterName
        } else {
            Write-Host "ERROR: setup-kind.ps1 not found" -ForegroundColor Red
            Write-Host "Please run this script from the k8s-lab directory" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "ERROR: Please specify 'minikube' or 'kind' as the environment type" -ForegroundColor Red
        exit 1
    }
}

function Stop-Cluster {
    param(
        [string]$EnvType,
        [string]$ClusterName
    )
    
    if ([string]::IsNullOrEmpty($EnvType)) {
        Write-Host "ERROR: Please specify 'minikube' or 'kind' as the environment type" -ForegroundColor Red
        exit 1
    }
    
    if ($EnvType -eq 'minikube') {
        Test-Tool 'minikube'
        
        # Set default minikube cluster name if not provided
        if ([string]::IsNullOrEmpty($ClusterName)) {
            $ClusterName = 'minikube-multi-node'
        }
        
        Write-Host "Stopping Minikube cluster: $ClusterName" -ForegroundColor Yellow
        minikube stop -p $ClusterName
    }
    elseif ($EnvType -eq 'kind') {
        Test-Tool 'kind'
        
        # Set default kind cluster name if not provided
        if ([string]::IsNullOrEmpty($ClusterName)) {
            $ClusterName = 'kind-multi-node'
        }
        
        Write-Host "KIND doesn't have a stop feature. Use 'cleanup' to remove the cluster." -ForegroundColor Red
        Write-Host "If you want to free resources, you can stop the Docker containers manually." -ForegroundColor Yellow
    }
    else {
        Write-Host "ERROR: Please specify 'minikube' or 'kind' as the environment type" -ForegroundColor Red
        exit 1
    }
}

function Get-ClusterStatus {
    param([string]$EnvType)
    
    Write-Host "[*] Checking Kubernetes Cluster Status:" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Blue
    
    if ([string]::IsNullOrEmpty($EnvType) -or $EnvType -eq 'minikube') {
        if (Get-Command minikube -ErrorAction SilentlyContinue) {
            Write-Host "Minikube Clusters:" -ForegroundColor Yellow
            minikube profile list
            Write-Host ""
        }
    }
    
    if ([string]::IsNullOrEmpty($EnvType) -or $EnvType -eq 'kind') {
        if (Get-Command kind -ErrorAction SilentlyContinue) {
            Write-Host "Kind Clusters:" -ForegroundColor Yellow
            kind get clusters
            Write-Host ""
        }
    }
    
    if (Get-Command kubectl -ErrorAction SilentlyContinue) {
        Write-Host "Kubernetes Contexts:" -ForegroundColor Cyan
        kubectl config get-contexts
        Write-Host ""
        
        Write-Host "Current Context:" -ForegroundColor Cyan
        kubectl config current-context
    }
}

function Deploy-Demo {
    param(
        [string]$EnvType,
        [string]$ClusterName
    )
    
    if ([string]::IsNullOrEmpty($EnvType)) {
        Write-Host "ERROR: Please specify 'minikube' or 'kind' as the environment type" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "Deploying demo application to $EnvType cluster: $ClusterName" -ForegroundColor Green
    
    # Change to the demo-app directory before running the deploy script
    if (Test-Path "demo-app") {
        Push-Location -Path "demo-app"
        try {
            if (Test-Path ".\deploy-demo.ps1") {
                & ".\deploy-demo.ps1" $EnvType $ClusterName
            } else {
                Write-Host "ERROR: deploy-demo.ps1 not found in demo-app directory" -ForegroundColor Red
                Write-Host "Please run this script from the k8s-lab directory" -ForegroundColor Yellow
            }
        } finally {
            Pop-Location
        }
    } else {
        Write-Host "ERROR: demo-app directory not found" -ForegroundColor Red
        Write-Host "Please run this script from the k8s-lab directory" -ForegroundColor Yellow
    }
}

function Deploy-AdvancedDemo {
    param(
        [string]$EnvType,
        [string]$ClusterName,
        [string]$DemoType = 'all'
    )
    
    if ([string]::IsNullOrEmpty($EnvType)) {
        Write-Host "ERROR: Please specify 'minikube' or 'kind' as the environment type" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "Deploying advanced demo applications to $EnvType cluster: $ClusterName" -ForegroundColor Green
    
    # Change to the advanced-demos directory before running the deploy script
    if (Test-Path "demo-app\advanced-demos") {
        Push-Location -Path "demo-app\advanced-demos"
        try {
            if (Test-Path ".\deploy-advanced-demos.ps1") {
                & ".\deploy-advanced-demos.ps1" $EnvType $ClusterName $DemoType
            } else {
                Write-Host "ERROR: deploy-advanced-demos.ps1 not found in advanced-demos directory" -ForegroundColor Red
                Write-Host "Please run this script from the k8s-lab directory" -ForegroundColor Yellow
            }
        } finally {
            Pop-Location
        }
    } else {
        Write-Host "ERROR: demo-app\advanced-demos directory not found" -ForegroundColor Red
        Write-Host "Please run this script from the k8s-lab directory" -ForegroundColor Yellow
    }
}

function Open-Dashboard {
    param(
        [string]$EnvType,
        [string]$ClusterName
    )
    
    if ([string]::IsNullOrEmpty($EnvType)) {
        Write-Host "ERROR: Please specify 'minikube' or 'kind' as the environment type" -ForegroundColor Red
        exit 1
    }
    
    if ($EnvType -eq 'minikube') {
        Test-Tool 'minikube'
        
        # Set default minikube cluster name if not provided
        if ([string]::IsNullOrEmpty($ClusterName)) {
            $ClusterName = 'minikube-multi-node'
        }
        
        Write-Host "Opening Kubernetes Dashboard for Minikube: $ClusterName" -ForegroundColor Green
        minikube dashboard -p $ClusterName
    }
    elseif ($EnvType -eq 'kind') {
        # Check if k9s is installed
        if (-not (Get-Command k9s -ErrorAction SilentlyContinue)) {
            Write-Host "K9s tool is not installed" -ForegroundColor Yellow
            Write-Host "For better Kind cluster management, we recommend installing K9s:" -ForegroundColor Cyan
            Write-Host "   choco install k9s (Windows with Chocolatey)" -ForegroundColor Cyan
            Write-Host "   scoop install k9s (Windows with Scoop)" -ForegroundColor Cyan
            Write-Host "Using kubectl instead..." -ForegroundColor Cyan
            
            # Set default kind cluster name if not provided
            if ([string]::IsNullOrEmpty($ClusterName)) {
                $ClusterName = 'kind-multi-node'
            }
            
            # Make sure we're using the correct Kind context
            kubectl config use-context "kind-$ClusterName"
            
            # Show some helpful output instead
            Write-Host "================================================================" -ForegroundColor Blue
            Write-Host "Showing Kind Cluster Info:" -ForegroundColor Cyan
            
            Write-Host "Nodes:" -ForegroundColor Yellow
            kubectl get nodes -o wide
            
            Write-Host "Pods:" -ForegroundColor Yellow
            kubectl get pods -A
        } else {
            Write-Host "Opening K9s for Kind cluster management" -ForegroundColor Green
            
            # Set default kind cluster name if not provided
            if ([string]::IsNullOrEmpty($ClusterName)) {
                $ClusterName = 'kind-multi-node'
            }
            
            # Make sure we're using the correct Kind context
            kubectl config use-context "kind-$ClusterName"
            
            # Launch k9s
            k9s
        }
    }
    else {
        Write-Host "ERROR: Please specify 'minikube' or 'kind' as the environment type" -ForegroundColor Red
        exit 1
    }
}

function Remove-Cluster {
    param(
        [string]$EnvType,
        [string]$ClusterName
    )
    
    if ([string]::IsNullOrEmpty($EnvType)) {
        Write-Host "ERROR: Please specify 'minikube' or 'kind' as the environment type" -ForegroundColor Red
        exit 1
    }
    
    if ($EnvType -eq 'minikube') {
        Test-Tool 'minikube'
        
        # Set default minikube cluster name if not provided
        if ([string]::IsNullOrEmpty($ClusterName)) {
            $ClusterName = 'minikube-multi-node'
        }
        
        Write-Host "WARNING: Cleaning up Minikube cluster: $ClusterName" -ForegroundColor Red
        Write-Host "This will delete the cluster and all related resources." -ForegroundColor Yellow
        
        $confirm = Read-Host "Are you sure you want to proceed? (y/n)"
        if ($confirm -eq 'y' -or $confirm -eq 'Y' -or $confirm -eq 'yes' -or $confirm -eq 'Yes') {
            minikube delete -p $ClusterName
            Write-Host "Cluster $ClusterName has been deleted" -ForegroundColor Green
        } else {
            Write-Host "Cleanup cancelled" -ForegroundColor Yellow
        }
    }
    elseif ($EnvType -eq 'kind') {
        Test-Tool 'kind'
        
        # Set default kind cluster name if not provided
        if ([string]::IsNullOrEmpty($ClusterName)) {
            $ClusterName = 'kind-multi-node'
        }
        
        Write-Host "WARNING: Cleaning up Kind cluster: $ClusterName" -ForegroundColor Red
        Write-Host "This will delete the cluster and all related resources." -ForegroundColor Yellow
        
        $confirm = Read-Host "Are you sure you want to proceed? (y/n)"
        if ($confirm -eq 'y' -or $confirm -eq 'Y' -or $confirm -eq 'yes' -or $confirm -eq 'Yes') {
            kind delete cluster --name $ClusterName
            Write-Host "Cluster $ClusterName has been deleted" -ForegroundColor Green
        } else {
            Write-Host "Cleanup cancelled" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "ERROR: Please specify 'minikube' or 'kind' as the environment type" -ForegroundColor Red
        exit 1
    }
}

# Main script execution
Show-Header

switch ($Command) {
    'start' {
        Start-Cluster -EnvType $Environment -ClusterName $ClusterName
    }
    'stop' {
        Stop-Cluster -EnvType $Environment -ClusterName $ClusterName
    }
    'status' {
        Get-ClusterStatus -EnvType $Environment
    }
    'deploy-demo' {
        Deploy-Demo -EnvType $Environment -ClusterName $ClusterName
    }
    'deploy-advanced' {
        Deploy-AdvancedDemo -EnvType $Environment -ClusterName $ClusterName -DemoType $DemoType
    }
    'dashboard' {
        Open-Dashboard -EnvType $Environment -ClusterName $ClusterName
    }
    'cleanup' {
        Remove-Cluster -EnvType $Environment -ClusterName $ClusterName
    }
    'help' {
        Show-Help
    }
    default {
        Write-Host "ERROR: Unknown command '$Command'" -ForegroundColor Red
        Show-Help
        exit 1
    }
}
