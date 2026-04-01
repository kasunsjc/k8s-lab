#!/usr/bin/env pwsh

<#
.SYNOPSIS
    🔷 🚀 Multi-Node Minikube Lab Setup Script for Windows 🚀 🔷

.DESCRIPTION
    Script to set up a multi-node Minikube cluster on Windows
    
.PARAMETER ProfileName
    The name of the Minikube profile to create (default: minikube-multinode)

.EXAMPLE
    .\setup-minikube.ps1
    .\setup-minikube.ps1 my-cluster
#>

param(
    [Parameter(Position=0)]
    [string]$ProfileName = 'minikube-multi-node'
)

# Enable strict mode for better error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host "🖥️  Detected OS: Windows" -ForegroundColor Cyan
Write-Host "🚀 Setting up a multi-node Minikube cluster with profile: $ProfileName" -ForegroundColor Yellow

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
    
    # Check if Minikube is installed
    if (-not (Get-Command minikube -ErrorAction SilentlyContinue)) {
        Write-Host "Installing Minikube..." -ForegroundColor Yellow
        choco install minikube -y
        
        # Refresh environment variables
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        
        if (-not (Get-Command minikube -ErrorAction SilentlyContinue)) {
            Write-Host "❌ Failed to install Minikube. Please install it manually and run this script again." -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "✅ Minikube is already installed." -ForegroundColor Green
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
    
    # Check if Docker Desktop is running (required for Minikube)
    try {
        docker version | Out-Null
        Write-Host "✅ Docker is running." -ForegroundColor Green
    } catch {
        Write-Host "❌ Docker is not running. Please start Docker Desktop and run this script again." -ForegroundColor Red
        Write-Host "💡 Minikube requires Docker Desktop to be running on Windows." -ForegroundColor Yellow
        exit 1
    }
}

# Function to create multi-node Minikube cluster
function New-MinikubeCluster {
    Write-Host "🚀 Creating multi-node Minikube cluster with profile: $ProfileName" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
    
    # Configuration for the cluster
    $cpus = 2
    $memory = '2g'
    $nodes = 3  # Multi-node cluster
    $driver = 'docker'
    
    Write-Host "📋 Cluster Configuration:" -ForegroundColor Yellow
    Write-Host "   • Profile: $ProfileName" -ForegroundColor White
    Write-Host "   • Driver: $driver" -ForegroundColor White
    Write-Host "   • Nodes: $nodes (1 control-plane + 2 workers)" -ForegroundColor White
    Write-Host "   • CPUs per node: $cpus" -ForegroundColor White
    Write-Host "   • Memory per node: $memory" -ForegroundColor White
    Write-Host ""
    
    # Check if profile already exists
    try {
        $profiles = minikube profile list -o json 2>$null | ConvertFrom-Json
        $existingProfile = $profiles.valid | Where-Object { $_.Name -eq $ProfileName }
        
        if ($existingProfile) {
            Write-Host "⚠️  Profile '$ProfileName' already exists!" -ForegroundColor Yellow
            $response = Read-Host "Do you want to delete and recreate it? (y/n)"
            
            if ($response -eq 'y' -or $response -eq 'Y' -or $response -eq 'yes' -or $response -eq 'Yes') {
                Write-Host "🗑️  Deleting existing profile..." -ForegroundColor Red
                minikube delete -p $ProfileName
                Write-Host "✅ Existing profile deleted." -ForegroundColor Green
            } else {
                Write-Host "❌ Aborted. Use a different profile name or delete the existing one manually." -ForegroundColor Red
                exit 1
            }
        }
    } catch {
        # Profile doesn't exist or error getting profiles, continue with creation
    }
    
    # Start creating the cluster
    Write-Host "🔄 Starting Minikube cluster creation..." -ForegroundColor Yellow
    Write-Host "⏳ This may take several minutes..." -ForegroundColor Yellow
    
    try {
        # Create the cluster with multi-node configuration
        Write-Host "Creating multi-node cluster with profile: $ProfileName" -ForegroundColor Cyan
        Write-Host "Using multi-node configuration with $nodes nodes..." -ForegroundColor Yellow
        
        minikube start `
            --profile=$ProfileName `
            --driver=$driver `
            --nodes=$nodes `
            --cpus=$cpus `
            --memory=$memory `
            --kubernetes-version=stable
        
        if ($LASTEXITCODE -ne 0) {
            throw "Minikube start failed"
        }
        
        Write-Host "✅ Minikube multi-node cluster created successfully!" -ForegroundColor Green
        
    } catch {
        Write-Host "❌ Failed to create Minikube cluster: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "💡 Try running: minikube delete -p $ProfileName and then re-run this script." -ForegroundColor Yellow
        exit 1
    }
}

# Function to verify cluster
function Test-ClusterHealth {
    Write-Host "🔍 Verifying cluster health..." -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
    
    # Set context to our cluster
    kubectl config use-context $ProfileName
    
    # Wait for nodes to be ready
    Write-Host "⏳ Waiting for nodes to be ready..." -ForegroundColor Yellow
    $timeout = 120 # 2 minutes - reduced timeout
    $elapsed = 0
    
    do {
        try {
            $nodes = kubectl get nodes --no-headers 2>$null
            if ($nodes) {
                $readyNodes = ($nodes | Where-Object { $_ -match '\s+Ready\s+' }).Count
                $totalNodes = ($nodes | Measure-Object).Count
                
                if ($readyNodes -eq $totalNodes -and $totalNodes -gt 0) {
                    Write-Host "✅ All $totalNodes nodes are ready!" -ForegroundColor Green
                    break
                }
                
                Write-Host "⏳ $readyNodes/$totalNodes nodes ready. Waiting..." -ForegroundColor Yellow
            } else {
                Write-Host "⏳ Waiting for nodes to appear..." -ForegroundColor Yellow
            }
            
            Start-Sleep -Seconds 5
            $elapsed += 5
            
        } catch {
            Write-Host "⏳ Waiting for cluster to be accessible..." -ForegroundColor Yellow
            Start-Sleep -Seconds 5
            $elapsed += 5
        }
        
    } while ($elapsed -lt $timeout)
    
    # If timeout, still try to show cluster info (it might be working anyway)
    if ($elapsed -ge $timeout) {
        Write-Host "⚠️  Timeout waiting for nodes, but cluster might still be functional." -ForegroundColor Yellow
        Write-Host "Checking cluster status..." -ForegroundColor Cyan
    }
    
    # Display cluster information
    Write-Host ""
    Write-Host "📊 Cluster Information:" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
    
    Write-Host "🔗 Cluster Info:" -ForegroundColor Yellow
    kubectl cluster-info
    
    Write-Host ""
    Write-Host "📋 Nodes:" -ForegroundColor Yellow
    kubectl get nodes -o wide
    
    Write-Host ""
    Write-Host "🏃 Running Pods:" -ForegroundColor Yellow
    kubectl get pods -A
}

# Function to enable useful addons
function Enable-MinikubeAddons {
    Write-Host ""
    Write-Host "🔌 Enabling useful Minikube addons..." -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
    
    $addons = @(
        'dashboard',
        'metrics-server',
        'ingress'
    )
    
    foreach ($addon in $addons) {
        try {
            Write-Host "🔄 Enabling $addon..." -ForegroundColor Yellow
            minikube addons enable $addon -p $ProfileName
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✅ $addon enabled successfully!" -ForegroundColor Green
            } else {
                Write-Host "⚠️  Failed to enable $addon" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "⚠️  Failed to enable $addon : $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

# Function to show next steps
function Show-NextSteps {
    Write-Host ""
    Write-Host "🎉 Minikube Multi-Node Cluster Setup Complete!" -ForegroundColor Green
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
    Write-Host ""
    Write-Host "📋 Cluster Details:" -ForegroundColor Cyan
    Write-Host "   • Profile Name: $ProfileName" -ForegroundColor White
    Write-Host "   • Driver: docker" -ForegroundColor White
    Write-Host "   • Nodes: 3 (1 control-plane + 2 workers)" -ForegroundColor White
    Write-Host ""
    Write-Host "🔧 Useful Commands:" -ForegroundColor Cyan
    Write-Host "   • Check status:" -ForegroundColor White -NoNewline
    Write-Host " minikube status -p $ProfileName" -ForegroundColor Yellow
    Write-Host "   • Open dashboard:" -ForegroundColor White -NoNewline
    Write-Host " minikube dashboard -p $ProfileName" -ForegroundColor Yellow
    Write-Host "   • SSH to node:" -ForegroundColor White -NoNewline
    Write-Host " minikube ssh -p $ProfileName" -ForegroundColor Yellow
    Write-Host "   • Stop cluster:" -ForegroundColor White -NoNewline
    Write-Host " minikube stop -p $ProfileName" -ForegroundColor Yellow
    Write-Host "   • Delete cluster:" -ForegroundColor White -NoNewline
    Write-Host " minikube delete -p $ProfileName" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "🚀 Next Steps:" -ForegroundColor Cyan
    Write-Host "   • Deploy demo applications using the main k8s-lab.ps1 script" -ForegroundColor White
    Write-Host "   • Run:" -ForegroundColor White -NoNewline
    Write-Host " .\k8s-lab.ps1 deploy-demo minikube $ProfileName" -ForegroundColor Yellow
}

# Main execution
try {
    Write-Host "🔒 Checking administrator privileges..." -ForegroundColor Cyan
    if (-not (Test-Administrator)) {
        Write-Host "⚠️  This script requires administrator privileges for some operations." -ForegroundColor Yellow
        Write-Host "💡 Please run PowerShell as Administrator or ensure Chocolatey is already installed." -ForegroundColor Yellow
    }
    
    Install-Dependencies
    New-MinikubeCluster
    Test-ClusterHealth
    Enable-MinikubeAddons
    Show-NextSteps
    
} catch {
    Write-Host "❌ Setup failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "💡 Please check the error message above and try again." -ForegroundColor Yellow
    exit 1
}
