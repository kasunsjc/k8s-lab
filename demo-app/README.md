# 🚢 Demo Applications

This directory contains multiple demo applications that can be deployed to test Kubernetes clusters.

## 📋 What's Included

### Basic Demo Application
- `demo-app.yaml`: A simplified Google Microservices Demo application (Online Boutique)
- `k8s-dashboard.yaml`: Kubernetes Dashboard admin user configuration
- `deploy-demo.sh`: A script to deploy the demo application to either Minikube or Kind

### Advanced Demos
- `advanced-demos/`: ConfigMap, Secret, StatefulSet, and HPA examples
- `monitoring-demo/`: Prometheus and Grafana monitoring stack
- `istio-demo/`: Complete Istio service mesh demonstration

### 🕸️ Istio Service Mesh Demo

The `istio-demo/` directory contains a comprehensive Istio service mesh demonstration featuring:

- **Complete Istio installation via Helm**
- **BookInfo sample application** (polyglot microservices)
- **Traffic management** (canary deployments, A/B testing)
- **Security features** (mTLS, authorization policies)
- **Observability tools** (Kiali, Jaeger, Grafana, Prometheus)
- **Advanced patterns** (circuit breakers, fault injection)

Quick start:
```bash
cd istio-demo
./deploy-istio.sh
./test-istio.sh
```

For more details, see [istio-demo/README.md](istio-demo/README.md)

## 🚀 How to Deploy

After you have set up either a Minikube or Kind cluster, you can deploy the demo application using:

```bash
# For Minikube (default profile)
./deploy-demo.sh minikube

# For Minikube (custom profile)
./deploy-demo.sh minikube my-custom-profile

# For Kind (default cluster)
./deploy-demo.sh kind

# For Kind (custom cluster)
./deploy-demo.sh kind my-custom-cluster
```

## 🌐 Accessing the Demo

### For Minikube

There are two ways to access the application:

1. Using service:
   ```bash
   minikube service frontend -p <profile-name>
   ```

2. Using Ingress (requires tunnel):
   ```bash
   minikube tunnel -p <profile-name>
   # Then visit: http://localhost/
   ```

### For Kind

Since the Kind setup already exposes ports 80 and 443 to the host:

1. Simply visit:
   ```
   http://localhost/
   ```

## 🧹 Cleanup

To remove the demo application:

```bash
kubectl delete -f demo-app.yaml
kubectl delete -f k8s-dashboard.yaml  # For Minikube only
```

## 📊 Kubernetes Dashboard (Minikube only)

For Minikube, you can access the Kubernetes Dashboard with:

```bash
minikube dashboard -p <profile-name>
```

The `deploy-demo.sh` script already creates an admin user and provides a token for authentication.
