# 🚀 Kubernetes Multi-Node Development Clusters

[![🔶 Kind Lab Status](https://github.com/kasunsjc/k8s-lab/actions/workflows/verify-kind-cluster.yml/badge.svg)](https://github.com/kasunsjc/k8s-lab/actions/workflows/verify-kind-cluster.yml)
[![🔷 Minikube Lab Status](https://github.com/kasunsjc/k8s-lab/actions/workflows/verify-minikube-cluster.yml/badge.svg)](https://github.com/kasunsjc/k8s-lab/actions/workflows/verify-minikube-cluster.yml)
[![🚀 Daily Verification](https://github.com/kasunsjc/k8s-lab/actions/workflows/daily-verification.yml/badge.svg)](https://github.com/kasunsjc/k8s-lab/actions/workflows/daily-verification.yml)

This repository contains ready-to-use setup scripts and detailed instructions for creating powerful multi-node Kubernetes development clusters locally using two popular tools:

1. 🔷 **Minikube Lab** - A feature-rich multi-node Kubernetes cluster using Minikube
2. 🔶 **Kind Lab** - A lightweight multi-node Kubernetes cluster using Kind (Kubernetes IN Docker)

## 🆕 New Features

- 🔮 **All-in-one Management Script** - New `k8s-lab.sh` provides unified management for both types of clusters
- 🧠 **Smart Cluster Management** - Clusters are preserved and restarted rather than recreated when possible
- 🧩 **Advanced Demo Applications** - New demonstrations of StatefulSets, HPA, ConfigMaps and Secrets
- 📊 **Enhanced Status Checking** - Quick overview of all clusters and their state
- 🧹 **Cluster Cleanup** - Easy deletion and cleanup of clusters

## 🔎 Overview of the Labs

### 🔷 Minikube Lab

The Minikube lab creates a robust 3-node cluster with all nodes having the same role. It includes:

- 📊 Kubernetes Dashboard for visual management
- 📈 Metrics Server for performance monitoring
- 🌐 Ingress Controller for external access

Minikube provides a more VM-like experience and is optimized for local development with a focus on ease of use and comprehensive tooling.

### 🔶 Kind Lab

The Kind lab creates an efficient 3-node cluster with 1 control-plane node and 2 worker nodes. It includes:

- 📈 Metrics Server for resource monitoring
- 🌐 NGINX Ingress Controller with pre-configured ports

Kind is ultra-lightweight, extraordinarily fast to start up, and precisely designed for testing Kubernetes itself. It's particularly excellent for CI environments and testing multi-node configurations with minimal resource usage.

## 🤔 Choosing Between the Labs

- **Use Minikube if:**
  - 🏗️ You want an experience closer to a "real" Kubernetes cluster
  - 📊 You need the built-in dashboard for visual management
  - 🧩 You prefer a more guided approach with built-in addons
  - 🔄 You want consistent behavior across different environments

- **Use Kind if:**
  - ⚡ You want lightning-fast startup and teardown times
  - 🧪 You need to test specialized multi-role configurations
  - 🔄 You're implementing CI/CD testing pipelines
  - 🪶 You want the most lightweight solution possible

## 🚀 Quick Start

### Using the Unified Management Script

Our new unified management script makes it easier than ever to work with both types of clusters:

```bash
# Show available commands
./k8s-lab.sh help

# Start a Minikube cluster (with optional profile name)
./k8s-lab.sh start minikube [profile_name]

# Start a Kind cluster (with optional cluster name)
./k8s-lab.sh start kind [cluster_name]

# Check status of all clusters
./k8s-lab.sh status

# Deploy the basic demo app
./k8s-lab.sh deploy-demo minikube [profile_name]

# Open the dashboard (Minikube) or K9s (Kind)
./k8s-lab.sh dashboard minikube [profile_name]

# Clean up a cluster
./k8s-lab.sh cleanup kind [cluster_name]
```

> **💡 Smart Cluster Management**: When starting a cluster, the script automatically checks if it already exists.
> If a cluster with the same name is already running, no action is taken. If it exists but is stopped,
> the script will start it instead of recreating it. This saves time and preserves your workloads.

### Advanced Demo Applications

We now have advanced demos that showcase various Kubernetes features:

```bash
# Navigate to the advanced demos directory
cd demo-app/advanced-demos

# Deploy all advanced demos to Minikube
./deploy-advanced-demos.sh minikube [profile_name] all

# Deploy only the StatefulSet demo to Kind
./deploy-advanced-demos.sh kind [cluster_name] stateful

# Deploy only the HPA demo
./deploy-advanced-demos.sh minikube [profile_name] hpa
```

See the README in the `demo-app/advanced-demos` directory for more details.

## 🔄 Automated Testing & Verification

This repository includes comprehensive GitHub Actions workflows that automatically verify the functionality of both lab setups:

### 🤖 Automated Workflows

- **🔶 Kind Lab Verification** - Tests Kind cluster setup, demo deployments, and advanced features
- **🔷 Minikube Lab Verification** - Tests Minikube cluster setup, addons, and all demo applications  
- **🚀 Daily Verification** - Runs both tests daily to ensure labs remain functional

### 📊 Status Monitoring

The badges at the top of this README show real-time status:

- **Green ✅** - Lab setup is working correctly
- **Red ❌** - Issues detected, check the workflow logs
- **Yellow 🟡** - Tests are currently running

### 🔧 What Gets Tested

Each workflow verifies:

- ✅ Cluster creation and node health
- ✅ System component readiness (metrics-server, dashboard, etc.)
- ✅ Demo application deployment and functionality
- ✅ Advanced demos (StatefulSets, HPA, ConfigMaps)
- ✅ Service accessibility and networking
- ✅ Resource cleanup and teardown

You can manually trigger these tests anytime by going to the **Actions** tab in the GitHub repository.

### 🧪 Manual Testing

For development and testing purposes, you can manually trigger the verification workflows using the GitHub CLI:

```bash
# Trigger Kind lab verification on current branch
gh workflow run verify-kind-cluster.yml

# Trigger Minikube lab verification on current branch
gh workflow run verify-minikube-cluster.yml

# Trigger daily verification
gh workflow run daily-verification.yml
```

> **Note:** This requires GitHub CLI (`gh`) to be installed and authenticated.
>
> **Important:** Workflows must exist on the specified branch to be triggered. If you're testing on a feature branch, make sure the workflow files are committed to that branch.

### Manual Setup

You can also navigate to either the `minikube-lab` or `kind-lab` directory and follow the instructions in their respective README files. Both labs feature simple setup scripts that handle all the complexity for you.

## 📋 Requirements for Both Labs

- 💻 macOS or Linux operating system
- 🐳 Docker installed and running
- 🧰 Terminal access
- 🔧 Basic command-line familiarity

## 🌟 Features

- ✅ Multi-node clusters for realistic testing
- ✅ Cross-platform support (macOS & Linux)
- ✅ Profile/naming support for running multiple clusters
- ✅ Smart cluster management that preserves and restarts existing clusters
- ✅ Pre-configured with essential add-ons
- ✅ Detailed documentation with examples
- ✅ Advanced demos of key Kubernetes features (StatefulSets, HPA, ConfigMaps, etc.)
- ✅ Unified cluster management script
- ✅ **Automated daily verification** - GitHub Actions workflows test both setups daily
- ✅ **Continuous integration** - Status badges show real-time lab health
- ✅ **Quality assurance** - Comprehensive testing of cluster setup and demo deployments

## 📂 Repository Structure

```text
Kubernetes-Lab/
├── README.md                     # This file
├── k8s-lab.sh                    # Unified management script for all clusters
├── .github/                      # GitHub Actions workflows
│   └── workflows/
│       ├── verify-kind-cluster.yml      # Kind lab verification
│       ├── verify-minikube-cluster.yml  # Minikube lab verification
│       └── daily-verification.yml       # Daily automated testing
├── minikube-lab/                 # Minikube-specific files
│   ├── README.md                 # Minikube setup instructions
│   └── setup-minikube.sh         # Minikube cluster setup script
├── kind-lab/                     # Kind-specific files
│   ├── README.md                 # Kind setup instructions
│   ├── kind-config.yaml          # Kind cluster configuration
│   └── setup-kind.sh             # Kind cluster setup script
└── demo-app/                     # Demo applications
    ├── README.md                 # Demo app instructions
    ├── demo-app.yaml             # Basic demo application manifest
    ├── k8s-dashboard.yaml        # Dashboard configuration
    ├── deploy-demo.sh            # Demo deployment script
    └── advanced-demos/           # Advanced demonstrations
        ├── README.md             # Advanced demos documentation
        ├── stateful-mongodb.yaml # StatefulSet demo
        ├── hpa-demo.yaml         # HPA demo
        ├── configmap-secret-demo.yaml # ConfigMap and Secret demo
        └── deploy-advanced-demos.sh   # Advanced demos deployment script
```

## 🙏 Feedback and Contributions

Feedback and contributions are welcome! Feel free to open issues or submit pull requests to improve these labs.

## 🛠️ Troubleshooting

### Common Issues

**Cluster creation fails with port conflict:**
```
Error: port 80 or 443 is already in use
```
Stop any services using those ports (e.g., a local web server), or modify the Kind config to use alternate ports.

**Minikube status check fails:**
Ensure `jq` is installed for reliable JSON parsing: `brew install jq` (macOS) or `sudo apt install jq` (Linux).

**Docker is not running:**
Start Docker Desktop or the Docker daemon before running any cluster commands:
```bash
# macOS/Windows: Open Docker Desktop
# Linux:
sudo systemctl start docker
```

**kubectl context not set:**
```bash
# For Kind clusters
kubectl config use-context kind-<cluster-name>

# For Minikube clusters
minikube profile <profile-name>
```

**Metrics Server not working on Kind:**
The metrics server may need the `--kubelet-insecure-tls` flag. The setup scripts handle this automatically, but if you installed manually:
```bash
kubectl patch deployment metrics-server -n kube-system --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
```

**Ingress not accessible:**
- **Kind:** Ensure ports 80/443 are free and the NGINX Ingress Controller is running: `kubectl get pods -n ingress-nginx`
- **Minikube:** Run `minikube tunnel -p <profile>` to expose services
