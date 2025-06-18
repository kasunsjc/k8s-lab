# Kubernetes Multi-Node Development Clusters

This repository contains setup scripts and instructions for creating multi-node Kubernetes development clusters using two different tools:

1. **Minikube Lab** - A multi-node Kubernetes cluster using Minikube
2. **Kind Lab** - A multi-node Kubernetes cluster using Kind (Kubernetes IN Docker)

## Overview of the Labs

### Minikube Lab

The Minikube lab creates a 3-node cluster with all nodes having the same role. It includes:

- Kubernetes Dashboard
- Metrics Server
- Ingress Controller

Minikube provides a more VM-like experience and is optimized for local development with a focus on ease of use.

### Kind Lab

The Kind lab creates a 3-node cluster with 1 control-plane node and 2 worker nodes. It includes:

- Metrics Server
- NGINX Ingress Controller

Kind is lightweight, fast to start up, and designed for testing Kubernetes itself. It's particularly good for CI environments and testing of multi-node configurations.

## Choosing Between the Labs

- **Use Minikube if:**
  - You want an experience closer to a "real" Kubernetes cluster
  - You need the built-in dashboard
  - You prefer a more guided approach with built-in addons

- **Use Kind if:**
  - You want faster startup and teardown times
  - You need to test multi-role configurations
  - You're doing CI/CD testing
  - You want a more lightweight solution

## Getting Started

Navigate to either the `minikube-lab` or `kind-lab` directory and follow the instructions in their respective README files.

## Requirements for Both Labs

- macOS
- [Homebrew](https://brew.sh/)
- Docker Desktop
- Terminal access
