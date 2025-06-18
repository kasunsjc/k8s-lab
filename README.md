# 🚀 Kubernetes Multi-Node Development Clusters

This repository contains ready-to-use setup scripts and detailed instructions for creating powerful multi-node Kubernetes development clusters locally using two popular tools:

1. 🔷 **Minikube Lab** - A feature-rich multi-node Kubernetes cluster using Minikube
2. 🔶 **Kind Lab** - A lightweight multi-node Kubernetes cluster using Kind (Kubernetes IN Docker)

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

## 🏁 Getting Started

Navigate to either the `minikube-lab` or `kind-lab` directory and follow the instructions in their respective README files. Both labs feature simple setup scripts that handle all the complexity for you.

## 📋 Requirements for Both Labs

- 💻 macOS or Linux operating system
- 🐳 Docker installed and running
- 🧰 Terminal access
- 🔧 Basic command-line familiarity

## 🌟 Features

- ✅ Multi-node clusters for realistic testing
- ✅ Cross-platform support (macOS & Linux)
- ✅ Profile/naming support for running multiple clusters
- ✅ Pre-configured with essential add-ons
- ✅ Detailed documentation with examples
