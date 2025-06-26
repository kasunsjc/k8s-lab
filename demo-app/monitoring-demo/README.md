# 📊 Kubernetes Monitoring Demo

This demo shows how to set up a comprehensive monitoring stack for Kubernetes using the Prometheus Operator via Helm:

- 🔍 **Prometheus Operator** - Kubernetes native deployment and management of Prometheus and related monitoring components
- 📈 **Grafana** - Visualization and dashboards with pre-configured views 
- 🚨 **Alertmanager** - Handling alerts from Prometheus
- 📡 **Node Exporter** - Hardware and OS metrics collection
- 🔄 **kube-state-metrics** - Kubernetes object metrics collection
- 🧩 **Custom Resources** - ServiceMonitors, PodMonitors, and PrometheusRules for easy extension

## 🚀 Quick Start

To deploy the entire monitoring stack at once:

```bash
# Deploy the monitoring stack to Minikube
./deploy-monitoring.sh minikube [profile_name]

# OR deploy to Kind
./deploy-monitoring.sh kind [cluster_name]
```

## 🔍 What Gets Deployed

The deployment creates the following components:

1. **Namespace**: A dedicated `monitoring` namespace
2. **Prometheus**: Central metrics collection and storage
3. **Grafana**: Visualization with pre-configured dashboards
4. **Alertmanager**: Alert handling and notifications
5. **Node Exporter**: System-level metrics from each node
6. **kube-state-metrics**: Kubernetes object metrics
7. **Prometheus Operator**: Manages Prometheus components (CustomResourceDefinitions)

## 📈 Accessing the Dashboards

After deployment, you can access the dashboards using the provided convenience script:

```bash
# Access all dashboards
./start-monitoring.sh minikube [profile_name] all

# OR for Kind cluster
./start-monitoring.sh kind [cluster_name] all

# Access specific dashboard
./start-monitoring.sh minikube [profile_name] grafana
./start-monitoring.sh minikube [profile_name] prometheus
./start-monitoring.sh minikube [profile_name] alertmanager
```

### Manual Access Methods

#### For Minikube

```bash
# Get the Grafana URL (with port forwarding)
minikube service prometheus-grafana -n monitoring -p [profile_name]

# Get the Prometheus URL
minikube service prometheus-kube-prometheus-prometheus -n monitoring -p [profile_name]

# Get the Alertmanager URL
minikube service prometheus-kube-prometheus-alertmanager -n monitoring -p [profile_name]
```

#### For Kind

Since Kind doesn't provide a direct service URL, use port forwarding:

```bash
# Port forwarding for Grafana (access at http://localhost:3000)
kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring

# Port forwarding for Prometheus (access at http://localhost:9090)
kubectl port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090 -n monitoring

# Port forwarding for Alertmanager (access at http://localhost:9093)
kubectl port-forward svc/prometheus-kube-prometheus-alertmanager 9093:9093 -n monitoring
```

### Default Credentials

- **Grafana**: Username: `admin`, Password: `admin`
  (You'll be asked to change the password on first login)

## 🛠️ Key Features

- **Automatic discovery** of Kubernetes services and pods
- **Pre-configured dashboards** for nodes, pods, and Kubernetes objects
- **Resource usage visualization** for CPU, memory, disk, and network
- **Sample alerts** for common failure scenarios
- **Persistent storage** for metrics data (when available)
- **RBAC-enabled** with appropriate permissions

## 🧪 Testing the Monitoring

After deploying, you can generate some load to see metrics in action:

```bash
# Create a simple load generator
kubectl create deployment load-generator --image=busybox -- /bin/sh -c "while true; do wget -q -O- http://kubernetes.default.svc.cluster.local; done"

# Scale it up to generate more load
kubectl scale deployment load-generator --replicas=5

# When finished testing
kubectl delete deployment load-generator
```

## 📚 Included Dashboards

The Grafana installation comes with several pre-configured dashboards:

1. **Kubernetes Cluster Overview**: High-level cluster health and resource usage
2. **Node Performance**: Detailed metrics for each node
3. **Pod Resources**: CPU and memory usage for each pod
4. **Kubernetes State Metrics**: Health of k8s objects and components
5. **Prometheus Stats**: Monitoring your monitoring system

## ⚙️ Advanced Configuration

For advanced users, you can customize the deployment:

### Using values.yaml

The deployment uses a `values.yaml` file to customize the Helm chart. You can modify this file to:

- Adjust resource limits and requests
- Configure persistent storage for long-term metrics retention
- Add additional Grafana plugins and data sources
- Customize Alertmanager notification routes
- Enable additional features of the Prometheus Operator

### Additional Scrape Configurations

The `custom-values.yaml` contains additional scrape configurations that will be applied after deployment. You can modify this file to add custom scraping targets:

- Custom endpoints with annotations
- Static targets
- Example configuration for blackbox exporter for HTTP endpoint monitoring

### Extending with Custom Resources

You can use the Prometheus Operator Custom Resources to extend the monitoring:

```bash
# Example: Creating a ServiceMonitor for a custom application
kubectl apply -f - <<EOF
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: example-app
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: example-app
  endpoints:
  - port: web
EOF
```

## 🧹 Cleanup

To remove the monitoring stack:

```bash
# Option 1: Clean uninstall using Helm (preferred)
helm uninstall prometheus -n monitoring

# Option 2: Remove only the monitoring components but keep the namespace
kubectl delete prometheuses,alertmanagers,servicemonitors,podmonitors,prometheusrules -n monitoring --all
kubectl delete deployments,statefulsets,services,configmaps,secrets -l "app.kubernetes.io/part-of=kube-prometheus-stack" -n monitoring

# Option 3: Remove everything including the namespace
kubectl delete namespace monitoring
```

> **Note**: Option 1 is recommended as it correctly removes the Custom Resource Definitions and avoids orphaned resources.

## 📋 Requirements

- A running Kubernetes cluster (Minikube or Kind)
- kubectl installed and configured
- Helm v3+ installed
- At least 2GB of available memory for the monitoring components

## 🔧 Troubleshooting

### Common Issues

1. **CrashLoopBackOff in Prometheus pods**
   - Check if there's enough memory available
   - Check the Prometheus logs: `kubectl logs -n monitoring -l app=prometheus`
   - Consider increasing memory limits in `values.yaml`

2. **Missing metrics or targets**
   - Check service discovery: `kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090` and navigate to Status > Targets
   - Verify ServiceMonitor resources: `kubectl get servicemonitors -n monitoring`
   - Check for label selector mismatches between ServiceMonitors and Services

3. **Grafana dashboard issues**
   - Verify Prometheus data source is working
   - Check if dashboards are imported correctly: `kubectl get configmaps -n monitoring -l grafana_dashboard=1`

4. **PersistentVolumeClaim issues**
   - If using persistent storage, verify PVCs are bound: `kubectl get pvc -n monitoring`
   - For Minikube, ensure the storage addon is enabled: `minikube addons enable storage-provisioner`

### Checking Component Status

```bash
# Check all monitoring resources
kubectl get pods,svc,deployments,statefulsets -n monitoring

# Check Prometheus custom resources
kubectl get prometheuses,servicemonitors,podmonitors,alertmanagers -n monitoring

# Check Prometheus operator logs
kubectl logs -n monitoring -l app=prometheus-operator
```
