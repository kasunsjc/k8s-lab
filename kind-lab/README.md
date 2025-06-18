# Multi-Node Kind Lab Setup

This lab provides a multi-node Kubernetes development environment using Kind (Kubernetes IN Docker). The setup script is compatible with both macOS and Linux operating systems.

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
   chmod +x setup-kind.sh
   ```

2. Run the setup script:

   ```bash
   # Create a cluster with default name (kind-multi-node)
   ./setup-kind.sh
   
   # OR create a cluster with a custom name
   ./setup-kind.sh my-custom-cluster
   ```

   You can create multiple clusters with different names by specifying different cluster names.

## What This Lab Includes

- A 3-node Kubernetes cluster (1 control-plane, 2 workers) running on Docker
- Metrics Server
- NGINX Ingress Controller with ports 80 and 443 exposed to the host

## Using the Cluster

After setup, you can interact with your cluster using the following commands. Replace `<cluster-name>` with your cluster name (default is `kind-multi-node` if you didn't specify one).

```bash
# View nodes in the cluster
kubectl get nodes

# List all the pods in the cluster
kubectl get pods --all-namespaces

# Interact with a specific node
docker exec -it <cluster-name>-worker bash  # Connect to worker node
docker exec -it <cluster-name>-worker2 bash  # Connect to second worker node

# Delete the cluster when no longer needed
kind delete cluster --name <cluster-name>
```

## Deploying a Test Application

To test that your cluster is working correctly:

```bash
# Create a test deployment
kubectl create deployment nginx --image=nginx

# Expose the deployment
kubectl create service clusterip nginx --tcp=80:80

# Create an ingress resource
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nginx
            port:
              number: 80
EOF

# Test the ingress (once the ingress controller is ready)
curl http://localhost/
```

## Troubleshooting

If you encounter issues:

1. Ensure Docker Desktop is running with enough resources
2. Check the status of the ingress controller: `kubectl get pods -n ingress-nginx`
3. View logs for troubleshooting: `kubectl logs -n ingress-nginx <ingress-controller-pod-name>`
4. If the cluster fails to start, try increasing Docker's resource limits

## Additional Commands

```bash
# View cluster info
kubectl cluster-info

# View all contexts
kubectl config get-contexts

# Switch to the kind context if needed
kubectl config use-context kind-kind-multi-node
```

## Managing Multiple Clusters

You can create and manage multiple Kubernetes clusters by using different cluster names:

```bash
# Create a cluster with name "dev"
./setup-kind.sh dev

# Create another cluster with name "test" 
./setup-kind.sh test

# List all your Kind clusters
kind get clusters

# Switch kubectl context between clusters
kubectl config use-context kind-dev
kubectl config use-context kind-test

# Delete clusters when you're done with the labs
kind delete cluster --name dev
kind delete cluster --name test
```

Kind automatically prefixes your cluster name with "kind-" when creating kubectl contexts, so make sure to use "kind-{cluster-name}" when switching contexts.
