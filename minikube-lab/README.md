# Multi-Node Minikube Lab Setup

This lab provides a multi-node Kubernetes development environment using Minikube. The setup script is compatible with both macOS and Linux operating systems.

## Prerequisites

### For macOS

- macOS operating system
- [Homebrew](https://brew.sh/) package manager
- Docker Desktop installed and running

### For Linux

- Linux operating system (Ubuntu, Debian, CentOS, etc.)
- Docker installed and running
- `sudo` privileges (for installing dependencies)
- `curl` installed

## Setup Instructions

1. Make the setup script executable:

   ```bash
   chmod +x setup-minikube.sh
   ```

2. Run the setup script:

   ```bash
   # Create a cluster with default profile name (minikube-multinode)
   ./setup-minikube.sh
   
   # OR create a cluster with a specific profile name
   ./setup-minikube.sh my-custom-cluster
   ```

   You can create multiple clusters with different profiles by specifying different profile names.

## What This Lab Includes

- A 3-node Kubernetes cluster running on Docker
- Kubernetes Dashboard addon
- Metrics Server addon
- Ingress Controller addon

## Using the Cluster

After setup, you can interact with your cluster using the following commands. Replace `<profile-name>` with your profile name (default is `minikube-multinode` if you didn't specify one).

```bash
# View nodes in the cluster
kubectl get nodes

# Access the Kubernetes Dashboard
minikube dashboard -p <profile-name>

# SSH into a specific node
minikube ssh -p <profile-name> -n <profile-name>-m02  # Connect to node 2

# Stop the cluster when done
minikube stop -p <profile-name>

# Delete the cluster when no longer needed
minikube delete -p <profile-name>
```

## Troubleshooting

If you encounter issues:

1. Ensure Docker Desktop is running
2. Try restarting with `minikube stop -p <profile-name> && minikube start -p <profile-name> --nodes=3 --driver=docker`
3. Check logs with `minikube logs -p <profile-name>`

## Additional Commands

```bash
# View all minikube addons
minikube addons list -p <profile-name>

# Enable additional addons
minikube addons enable <addon-name> -p <profile-name>

# View cluster status
minikube status -p <profile-name>

# List all profiles (clusters) you've created
minikube profile list

# Switch between profiles
minikube profile <profile-name>
```

## Managing Multiple Clusters

You can create and manage multiple Kubernetes clusters by using different profile names:

```bash
# Create a cluster with profile "dev"
./setup-minikube.sh dev

# Create another cluster with profile "test" 
./setup-minikube.sh test

# List all your minikube profiles
minikube profile list

# Switch between profiles
minikube profile dev
minikube profile test

# Start specific profile
minikube start -p dev

# Stop specific profile
minikube stop -p dev

# Delete profiles when you're done with the labs
minikube delete -p dev
minikube delete -p test
```

## Driver Selection

The setup script automatically selects the best driver for your environment:

1. It first tries to use Docker if available (recommended)
2. On Linux, it will try to use KVM if available
3. On macOS, it will try to use HyperKit if available
4. If none of the above are available, it will fall back to VirtualBox

You can override the driver selection by modifying the script and changing the `DRIVER` variable.

For optimal performance:

- On Linux: Install KVM (`sudo apt-get install qemu-kvm libvirt-daemon-system`)
- On macOS: Use the default Docker driver which is recommended
