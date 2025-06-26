#!/bin/bash
# Helper script to add direct scrape configurations to Prometheus in CI environments
set -e

echo "Adding direct scrape configurations to Prometheus for CI environment"

# Create a ConfigMap with direct scrape configurations
kubectl create configmap -n monitoring additional-scrape-configs --from-literal=prometheus-additional.yaml='
# Direct scrape configuration for CI environments
- job_name: kubernetes-services-direct
  kubernetes_sd_configs:
  - role: service
    namespaces:
      names:
      - monitoring
  relabel_configs:
  - source_labels: [__meta_kubernetes_service_name]
    action: keep
    regex: prometheus-kube-prometheus-.*|prometheus-grafana|.*metrics.*

- job_name: kubernetes-pods-direct
  kubernetes_sd_configs:
  - role: pod
    namespaces:
      names:
      - monitoring
  relabel_configs:
  - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
    action: keep
    regex: true
  - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
    action: replace
    target_label: __metrics_path__
    regex: (.+)
  - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
    action: replace
    regex: ([^:]+)(?::\d+)?;(\d+)
    replacement: $1:$2
    target_label: __address__
' --dry-run=client -o yaml | kubectl apply -f -

# Patch the Prometheus CR to use the additional scrape config
kubectl patch prometheus -n monitoring prometheus-kube-prometheus-prometheus --type=merge -p '
{
  "spec": {
    "additionalScrapeConfigs": {
      "name": "additional-scrape-configs", 
      "key": "prometheus-additional.yaml"
    }
  }
}'

echo "Waiting for Prometheus to pick up the new configuration..."
# Find and restart the Prometheus pod
PROM_POD=$(kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].metadata.name}')
echo "Restarting Prometheus pod $PROM_POD"
kubectl delete pod -n monitoring $PROM_POD

echo "Waiting for Prometheus to restart..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus -n monitoring --timeout=120s

echo "Direct scrape configurations added to Prometheus"
