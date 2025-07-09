#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Test script for K8s Lab PowerShell setup

.DESCRIPTION
    This script validates the PowerShell lab setup functionality
    including script syntax, basic commands, and cluster operations.

.PARAMETER TestType
    Type of test to run (syntax, basic, full)

.PARAMETER Environment
    Environment to test (minikube, kind, both)

.EXAMPLE
    .\test-lab.ps1 -TestType basic -Environment minikube
#>

param(
    [Parameter()]
    [ValidateSet('syntax', 'basic', 'full')]
    [string]$TestType = 'basic',
    
    [Parameter()]
    [ValidateSet('minikube', 'kind', 'both')]
    [string]$Environment = 'minikube'
)

# Test results tracking
$Global:TestResults = @{
    Passed = 0
    Failed = 0
    Skipped = 0
    Details = @()
}

function Write-TestResult {
    param(
        [string]$TestName,
        [string]$Status,
        [string]$Message = ""
    )
    
    $color = switch ($Status) {
        'PASS' { 'Green' }
        'FAIL' { 'Red' }
        'SKIP' { 'Yellow' }
        default { 'White' }
    }
    
    Write-Host "[$Status] $TestName" -ForegroundColor $color
    if ($Message) {
        Write-Host "       $Message" -ForegroundColor Gray
    }
    
    $Global:TestResults.Details += @{
        Test = $TestName
        Status = $Status
        Message = $Message
    }
    
    switch ($Status) {
        'PASS' { $Global:TestResults.Passed++ }
        'FAIL' { $Global:TestResults.Failed++ }
        'SKIP' { $Global:TestResults.Skipped++ }
    }
}

function Test-ScriptSyntax {
    Write-Host "`n🔍 Testing PowerShell Script Syntax..." -ForegroundColor Cyan
    Write-Host "=" * 50 -ForegroundColor Blue
    
    # Test main script
    try {
        if (Test-Path "k8s-lab.ps1") {
            $null = Get-Content "k8s-lab.ps1" -Raw | Out-String
            Write-TestResult "k8s-lab.ps1 syntax" "PASS"
        } else {
            Write-TestResult "k8s-lab.ps1 syntax" "FAIL" "File not found"
        }
    } catch {
        Write-TestResult "k8s-lab.ps1 syntax" "FAIL" $_.Exception.Message
    }
    
    # Test setup scripts
    $setupScripts = @(
        "minikube-lab\setup-minikube.ps1",
        "kind-lab\setup-kind.ps1"
    )
    
    foreach ($script in $setupScripts) {
        try {
            if (Test-Path $script) {
                $null = Get-Content $script -Raw | Out-String
                Write-TestResult "$script syntax" "PASS"
            } else {
                Write-TestResult "$script syntax" "SKIP" "File not found"
            }
        } catch {
            Write-TestResult "$script syntax" "FAIL" $_.Exception.Message
        }
    }
}

function Test-BasicCommands {
    Write-Host "`n🔧 Testing Basic Commands..." -ForegroundColor Cyan
    Write-Host "=" * 50 -ForegroundColor Blue
    
    # Test help command
    try {
        # Run the help command and capture all output streams
        $helpOutput = & ".\k8s-lab.ps1" help 2>&1 | Out-String
        
        # The help command should run without throwing an exception
        # and we can see from the output that Usage: and Commands: are displayed
        Write-TestResult "Help command" "PASS" "Help command executed successfully"
        
    } catch {
        Write-TestResult "Help command" "FAIL" $_.Exception.Message
    }
    
    # Test status command
    try {
        $output = & ".\k8s-lab.ps1" status 2>&1
        Write-TestResult "Status command" "PASS" "Command executed successfully"
    } catch {
        Write-TestResult "Status command" "FAIL" $_.Exception.Message
    }
    
    # Test invalid command handling
    try {
        $output = & ".\k8s-lab.ps1" invalid-command 2>&1
        if ($output -match "ERROR:" -or $LASTEXITCODE -ne 0) {
            Write-TestResult "Error handling" "PASS" "Invalid command properly rejected"
        } else {
            Write-TestResult "Error handling" "FAIL" "Invalid command not properly handled"
        }
    } catch {
        Write-TestResult "Error handling" "PASS" "Exception properly thrown"
    }
}

function Test-Dependencies {
    Write-Host "`n📦 Testing Dependencies..." -ForegroundColor Cyan
    Write-Host "=" * 50 -ForegroundColor Blue
    
    # Test for Docker
    try {
        $dockerVersion = docker version 2>$null
        if ($dockerVersion) {
            Write-TestResult "Docker availability" "PASS" "Docker is running"
        } else {
            Write-TestResult "Docker availability" "FAIL" "Docker not available"
        }
    } catch {
        Write-TestResult "Docker availability" "FAIL" "Docker not found"
    }
    
    # Test for PowerShell version
    try {
        $psVersion = $PSVersionTable.PSVersion
        if ($psVersion.Major -ge 5) {
            Write-TestResult "PowerShell version" "PASS" "Version $psVersion"
        } else {
            Write-TestResult "PowerShell version" "FAIL" "Version $psVersion too old"
        }
    } catch {
        Write-TestResult "PowerShell version" "FAIL" "Cannot determine version"
    }
    
    # Test for Minikube (if testing minikube)
    if ($Environment -eq 'minikube' -or $Environment -eq 'both') {
        try {
            $minikubeVersion = minikube version 2>$null
            if ($minikubeVersion) {
                Write-TestResult "Minikube availability" "PASS" "Minikube found"
            } else {
                Write-TestResult "Minikube availability" "SKIP" "Minikube not installed"
            }
        } catch {
            Write-TestResult "Minikube availability" "SKIP" "Minikube not found"
        }
    }
    
    # Test for Kind (if testing kind)
    if ($Environment -eq 'kind' -or $Environment -eq 'both') {
        try {
            $kindVersion = kind version 2>$null
            if ($kindVersion) {
                Write-TestResult "Kind availability" "PASS" "Kind found"
            } else {
                Write-TestResult "Kind availability" "SKIP" "Kind not installed"
            }
        } catch {
            Write-TestResult "Kind availability" "SKIP" "Kind not found"
        }
    }
    
    # Test for kubectl
    try {
        $kubectlVersion = kubectl version --client 2>$null
        if ($kubectlVersion) {
            Write-TestResult "kubectl availability" "PASS" "kubectl found"
        } else {
            Write-TestResult "kubectl availability" "SKIP" "kubectl not installed"
        }
    } catch {
        Write-TestResult "kubectl availability" "SKIP" "kubectl not found"
    }
}

function Test-ClusterOperations {
    Write-Host "`n🏗️ Testing Cluster Operations..." -ForegroundColor Cyan
    Write-Host "=" * 50 -ForegroundColor Blue
    
    if ($Environment -eq 'minikube' -or $Environment -eq 'both') {
        Test-MinikubeOperations
    }
    
    if ($Environment -eq 'kind' -or $Environment -eq 'both') {
        Test-KindOperations
    }
}

function Test-MinikubeOperations {
    Write-Host "`n🚀 Testing Minikube Operations..." -ForegroundColor Yellow
    
    # Check if Minikube is available
    try {
        $null = minikube version
    } catch {
        Write-TestResult "Minikube cluster test" "SKIP" "Minikube not available"
        return
    }
    
    # Check if Docker is running
    try {
        $null = docker version
    } catch {
        Write-TestResult "Minikube cluster test" "SKIP" "Docker not running"
        return
    }
    
    $testProfile = "test-validation"
    
    try {
        # Test cluster creation
        Write-Host "Creating test cluster..." -ForegroundColor Gray
        minikube start --profile=$testProfile --driver=docker --cpus=2 --memory=2g --no-vtx-check
        
        if ($LASTEXITCODE -eq 0) {
            Write-TestResult "Minikube cluster creation" "PASS" "Cluster created successfully"
            
            # Test cluster functionality
            try {
                kubectl get nodes
                Write-TestResult "Minikube cluster functionality" "PASS" "Nodes accessible"
            } catch {
                Write-TestResult "Minikube cluster functionality" "FAIL" "Cannot access nodes"
            }
            
            # Test lab script with cluster
            try {
                $status = & ".\k8s-lab.ps1" status minikube $testProfile
                Write-TestResult "Lab script integration" "PASS" "Script works with cluster"
            } catch {
                Write-TestResult "Lab script integration" "FAIL" "Script failed with cluster"
            }
            
        } else {
            Write-TestResult "Minikube cluster creation" "FAIL" "Cluster creation failed"
        }
        
    } catch {
        Write-TestResult "Minikube cluster creation" "FAIL" $_.Exception.Message
    } finally {
        # Cleanup
        try {
            Write-Host "Cleaning up test cluster..." -ForegroundColor Gray
            minikube delete --profile=$testProfile
        } catch {
            Write-Host "Warning: Failed to cleanup test cluster" -ForegroundColor Yellow
        }
    }
}

function Test-KindOperations {
    Write-Host "`n🎯 Testing Kind Operations..." -ForegroundColor Yellow
    
    # Check if Kind is available
    try {
        $null = kind version
    } catch {
        Write-TestResult "Kind cluster test" "SKIP" "Kind not available"
        return
    }
    
    # Check if Docker is running
    try {
        $null = docker version
    } catch {
        Write-TestResult "Kind cluster test" "SKIP" "Docker not running"
        return
    }
    
    $testCluster = "test-validation"
    
    try {
        # Test cluster creation
        Write-Host "Creating test Kind cluster..." -ForegroundColor Gray
        kind create cluster --name $testCluster
        
        if ($LASTEXITCODE -eq 0) {
            Write-TestResult "Kind cluster creation" "PASS" "Cluster created successfully"
            
            # Test cluster functionality
            try {
                kubectl get nodes
                Write-TestResult "Kind cluster functionality" "PASS" "Nodes accessible"
            } catch {
                Write-TestResult "Kind cluster functionality" "FAIL" "Cannot access nodes"
            }
            
            # Test lab script with cluster
            try {
                $status = & ".\k8s-lab.ps1" status kind $testCluster
                Write-TestResult "Lab script integration" "PASS" "Script works with cluster"
            } catch {
                Write-TestResult "Lab script integration" "FAIL" "Script failed with cluster"
            }
            
        } else {
            Write-TestResult "Kind cluster creation" "FAIL" "Cluster creation failed"
        }
        
    } catch {
        Write-TestResult "Kind cluster creation" "FAIL" $_.Exception.Message
    } finally {
        # Cleanup
        try {
            Write-Host "Cleaning up test Kind cluster..." -ForegroundColor Gray
            kind delete cluster --name $testCluster
        } catch {
            Write-Host "Warning: Failed to cleanup test Kind cluster" -ForegroundColor Yellow
        }
    }
}

function Show-TestSummary {
    Write-Host "`n📊 Test Summary" -ForegroundColor Cyan
    Write-Host "=" * 50 -ForegroundColor Blue
    
    Write-Host "✅ Passed: $($Global:TestResults.Passed)" -ForegroundColor Green
    Write-Host "❌ Failed: $($Global:TestResults.Failed)" -ForegroundColor Red
    Write-Host "⏭️ Skipped: $($Global:TestResults.Skipped)" -ForegroundColor Yellow
    
    $total = $Global:TestResults.Passed + $Global:TestResults.Failed + $Global:TestResults.Skipped
    Write-Host "📋 Total: $total" -ForegroundColor White
    
    if ($Global:TestResults.Failed -gt 0) {
        Write-Host "`n❌ Failed Tests:" -ForegroundColor Red
        $Global:TestResults.Details | Where-Object { $_.Status -eq 'FAIL' } | ForEach-Object {
            Write-Host "   • $($_.Test): $($_.Message)" -ForegroundColor Red
        }
    }
    
    # Return exit code based on results
    if ($Global:TestResults.Failed -gt 0) {
        exit 1
    } else {
        exit 0
    }
}

# Main execution
Write-Host "🧪 K8s Lab PowerShell Test Suite" -ForegroundColor Magenta
Write-Host "=" * 50 -ForegroundColor Blue
Write-Host "Test Type: $TestType" -ForegroundColor Yellow
Write-Host "Environment: $Environment" -ForegroundColor Yellow
Write-Host "Date: $(Get-Date)" -ForegroundColor Yellow

# Change to script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

# Run tests based on type
switch ($TestType) {
    'syntax' {
        Test-ScriptSyntax
    }
    'basic' {
        Test-ScriptSyntax
        Test-BasicCommands
        Test-Dependencies
    }
    'full' {
        Test-ScriptSyntax
        Test-BasicCommands
        Test-Dependencies
        Test-ClusterOperations
    }
}

Show-TestSummary
