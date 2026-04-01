#!/usr/bin/env pwsh

<#
.SYNOPSIS
    🔷 🚀 Multi-Node Kind Lab Setup Script for Windows 🚀 🔷

.DESCRIPTION
    Script to set up a multi-node Kind cluster on Windows
    
.PARAMETER ClusterName
    The name of the Kind cluster to create (default: kind-multi-node)

.EXAMPLE
    .\setup-kind.ps1
    .\setup-kind.ps1 my-kind-cluster
#>

param(
    [Parameter(Position=0)]
    [string]$ClusterName = 'kind-multi-node'
)

# Enable strict mode for better error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "🖥️  Detected OS: Windows" -ForegroundColor Cyan
Write-Host "🚀 Setting up a multi-node Kind cluster with name: $ClusterName" -ForegroundColor Yellow

# Function to test if running as administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Function to install dependencies
function Install-Dependencies {
    Write-Host "📦 Checking and installing dependencies..." -ForegroundColor Cyan
    
    # Check if Chocolatey is installed
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Host "Installing Chocolatey package manager..." -ForegroundColor Yellow
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        
        # Refresh environment variables
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    } else {
        Write-Host "✅ Chocolatey is already installed." -ForegroundColor Green
    }
    
    # Check if Kind is installed
    if (-not (Get-Command kind -ErrorAction SilentlyContinue)) {
        Write-Host "Installing Kind..." -ForegroundColor Yellow
        choco install kind -y
        
        # Refresh environment variables
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        
        if (-not (Get-Command kind -ErrorAction SilentlyContinue)) {
            Write-Host "❌ Failed to install Kind. Please install it manually and run this script again." -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "✅ Kind is already installed." -ForegroundColor Green
    }
    
    # Check if kubectl is installed
    if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
        Write-Host "Installing kubectl..." -ForegroundColor Yellow
        choco install kubernetes-cli -y
        
        # Refresh environment variables
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        
        if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
            Write-Host "❌ Failed to install kubectl. Please install it manually and run this script again." -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "✅ kubectl is already installed." -ForegroundColor Green
    }
    
    # Check if Docker Desktop is running (required for Kind)
    try {
        docker version | Out-Null
        Write-Host "✅ Docker is running." -ForegroundColor Green
    } catch {
        Write-Host "❌ Docker is not running. Please start Docker Desktop and run this script again." -ForegroundColor Red
        Write-Host "💡 Kind requires Docker Desktop to be running on Windows." -ForegroundColor Yellow
        exit 1
    }
}

# Function to create Kind configuration
function New-KindConfig {
    $configPath = ".\kind-config.yaml"
    
    $configContent = @"
# Kind cluster configuration for multi-node setup
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: $ClusterName
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
- role: worker
- role: worker
"@
    
    Write-Host "📝 Creating Kind configuration file..." -ForegroundColor Yellow
    $configContent | Out-File -FilePath $configPath -Encoding UTF8
    Write-Host "✅ Kind configuration created at: $configPath" -ForegroundColor Green
    
    return $configPath
}

# Function to create multi-node Kind cluster
function New-KindCluster {
    param([string]$ConfigPath)
    
    Write-Host "🚀 Creating multi-node Kind cluster with name: $ClusterName" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
    
    Write-Host "📋 Cluster Configuration:" -ForegroundColor Yellow
    Write-Host "   • Cluster Name: $ClusterName" -ForegroundColor White
    Write-Host "   • Nodes: 3 (1 control-plane + 2 workers)" -ForegroundColor White
    Write-Host "   • Port Mappings: 80:80, 443:443" -ForegroundColor White
    Write-Host "   • Config File: $ConfigPath" -ForegroundColor White
    Write-Host ""
    
    # Check if cluster already exists
    try {
        $existingClusters = kind get clusters 2>$null
        if ($existingClusters -contains $ClusterName) {
            Write-Host "⚠️  Cluster '$ClusterName' already exists!" -ForegroundColor Yellow
            $response = Read-Host "Do you want to delete and recreate it? (y/n)"
            
            if ($response -eq 'y' -or $response -eq 'Y' -or $response -eq 'yes' -or $response -eq 'Yes') {
                Write-Host "🗑️  Deleting existing cluster..." -ForegroundColor Red
                kind delete cluster --name $ClusterName
                Write-Host "✅ Existing cluster deleted." -ForegroundColor Green
            } else {
                Write-Host "❌ Aborted. Use a different cluster name or delete the existing one manually." -ForegroundColor Red
                exit 1
            }
        }
    } catch {
        # Cluster doesn't exist or error getting clusters, continue with creation
    }
    
    # Start creating the cluster
    Write-Host "🔄 Starting Kind cluster creation..." -ForegroundColor Yellow
    Write-Host "⏳ This may take several minutes..." -ForegroundColor Yellow
    
    try {
        # Create the cluster with the configuration file
        kind create cluster --config $ConfigPath --name $ClusterName
        
        if ($LASTEXITCODE -ne 0) {
            throw "Kind create cluster failed"
        }
        
        Write-Host "✅ Kind cluster created successfully!" -ForegroundColor Green
        
        # Set kubectl context
        kubectl config use-context "kind-$ClusterName"
        
    } catch {
        Write-Host "❌ Failed to create Kind cluster: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "💡 Try running: kind delete cluster --name $ClusterName and then re-run this script." -ForegroundColor Yellow
        exit 1
    }
}

# Function to verify cluster
function Test-ClusterHealth {
    Write-Host "🔍 Verifying cluster health..." -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
    
    # Set context to our cluster
    kubectl config use-context "kind-$ClusterName"
    
    # Wait for nodes to be ready
    Write-Host "⏳ Waiting for nodes to be ready..." -ForegroundColor Yellow
    $timeout = 300 # 5 minutes
    $elapsed = 0
    
    do {
        try {
            $nodes = kubectl get nodes --no-headers 2>$null
            $readyNodes = ($nodes | Where-Object { $_ -match '\s+Ready\s+' }).Count
            $totalNodes = ($nodes | Measure-Object).Count
            
            if ($readyNodes -eq $totalNodes -and $totalNodes -gt 0) {
                Write-Host "✅ All $totalNodes nodes are ready!" -ForegroundColor Green
                break
            }
            
            Write-Host "⏳ $readyNodes/$totalNodes nodes ready. Waiting..." -ForegroundColor Yellow
            Start-Sleep -Seconds 10
            $elapsed += 10
            
        } catch {
            Write-Host "⏳ Waiting for cluster to be accessible..." -ForegroundColor Yellow
            Start-Sleep -Seconds 10
            $elapsed += 10
        }
        
    } while ($elapsed -lt $timeout)
    
    if ($elapsed -ge $timeout) {
        Write-Host "❌ Timeout waiting for nodes to be ready." -ForegroundColor Red
        exit 1
    }
    
    # Display cluster information
    Write-Host ""
    Write-Host "📊 Cluster Information:" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
    
    Write-Host "🔗 Cluster Info:" -ForegroundColor Yellow
    kubectl cluster-info --context "kind-$ClusterName"
    
    Write-Host ""
    Write-Host "📋 Nodes:" -ForegroundColor Yellow
    kubectl get nodes -o wide
    
    Write-Host ""
    Write-Host "🏃 Running Pods:" -ForegroundColor Yellow
    kubectl get pods -A
}

# Function to install useful tools
function Install-KindTools {
    Write-Host ""
    Write-Host "🔧 Installing useful tools for Kind..." -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
    
    # Install ingress controller
    Write-Host "🔄 Installing NGINX Ingress Controller..." -ForegroundColor Yellow
    try {
        kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
        
        # Wait for ingress controller to be ready
        Write-Host "⏳ Waiting for ingress controller to be ready..." -ForegroundColor Yellow
        kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=90s
        
        Write-Host "✅ NGINX Ingress Controller installed successfully!" -ForegroundColor Green
    } catch {
        Write-Host "⚠️  Failed to install NGINX Ingress Controller: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    # Check if k9s is available
    if (-not (Get-Command k9s -ErrorAction SilentlyContinue)) {
        Write-Host "💡 Consider installing k9s for better cluster management:" -ForegroundColor Cyan
        Write-Host "   choco install k9s" -ForegroundColor Yellow
        Write-Host "   scoop install k9s" -ForegroundColor Yellow
    } else {
        Write-Host "✅ k9s is already installed." -ForegroundColor Green
    }
}

# Function to show next steps
function Show-NextSteps {
    Write-Host ""
    Write-Host "🎉 Kind Multi-Node Cluster Setup Complete!" -ForegroundColor Green
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
    Write-Host ""
    Write-Host "📋 Cluster Details:" -ForegroundColor Cyan
    Write-Host "   • Cluster Name: $ClusterName" -ForegroundColor White
    Write-Host "   • Context: kind-$ClusterName" -ForegroundColor White
    Write-Host "   • Nodes: 3 (1 control-plane + 2 workers)" -ForegroundColor White
    Write-Host "   • Port Mappings: 80:80, 443:443" -ForegroundColor White
    Write-Host ""
    Write-Host "🔧 Useful Commands:" -ForegroundColor Cyan
    Write-Host "   • Check cluster status:" -ForegroundColor White -NoNewline
    Write-Host " kind get clusters" -ForegroundColor Yellow
    Write-Host "   • Switch context:" -ForegroundColor White -NoNewline
    Write-Host " kubectl config use-context kind-$ClusterName" -ForegroundColor Yellow
    Write-Host "   • Get nodes:" -ForegroundColor White -NoNewline
    Write-Host " kubectl get nodes" -ForegroundColor Yellow
    Write-Host "   • Delete cluster:" -ForegroundColor White -NoNewline
    Write-Host " kind delete cluster --name $ClusterName" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "🌐 Networking:" -ForegroundColor Cyan
    Write-Host "   • Ingress Controller: NGINX (installed)" -ForegroundColor White
    Write-Host "   • HTTP Port: 80 (mapped to host)" -ForegroundColor White
    Write-Host "   • HTTPS Port: 443 (mapped to host)" -ForegroundColor White
    Write-Host ""
    Write-Host "🚀 Next Steps:" -ForegroundColor Cyan
    Write-Host "   • Deploy demo applications using the main k8s-lab.ps1 script" -ForegroundColor White
    Write-Host "   • Run:" -ForegroundColor White -NoNewline
    Write-Host " .\k8s-lab.ps1 deploy-demo kind $ClusterName" -ForegroundColor Yellow
    Write-Host "   • Or open k9s for cluster management:" -ForegroundColor White -NoNewline
    Write-Host " k9s" -ForegroundColor Yellow
}

# Main execution
try {
    Write-Host "🔒 Checking administrator privileges..." -ForegroundColor Cyan
    if (-not (Test-Administrator)) {
        Write-Host "⚠️  This script requires administrator privileges for some operations." -ForegroundColor Yellow
        Write-Host "💡 Please run PowerShell as Administrator or ensure Chocolatey is already installed." -ForegroundColor Yellow
    }
    
    Install-Dependencies
    $configPath = New-KindConfig
    New-KindCluster -ConfigPath $configPath
    Test-ClusterHealth
    Install-KindTools
    Show-NextSteps
    
} catch {
    Write-Host "❌ Setup failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "💡 Please check the error message above and try again." -ForegroundColor Yellow
    exit 1
} finally {
    # Clean up config file
    if (Test-Path ".\kind-config.yaml") {
        Remove-Item ".\kind-config.yaml" -Force
    }
}
