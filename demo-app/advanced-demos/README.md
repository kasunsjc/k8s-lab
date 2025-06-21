# 🚀 Advanced Kubernetes Demo Applications

This directory contains advanced Kubernetes demonstration applications that showcase various Kubernetes features. These demonstrations go beyond basic deployments, highlighting more complex Kubernetes capabilities such as StatefulSets, Horizontal Pod Autoscaling (HPA), and ConfigMaps/Secrets.

## 📋 Available Demonstrations

### 1️⃣ MongoDB StatefulSet Demo

**Description:** This demo showcases how to run a stateful application (MongoDB) in Kubernetes using StatefulSets with persistent volumes. It includes:

- 📊 A MongoDB StatefulSet with 3 replicas
- 💾 Persistent Volume Claims for each MongoDB instance
- 🔄 Headless service for stable network identities
- 🖥️ Mongo Express UI for database management

**Features Demonstrated:**

- StatefulSets for ordered, stable deployment of pods
- Persistent Volume Claims for data persistence
- Headless Services for direct pod addressing
- Deployment of a web-based management UI

### 2️⃣ Horizontal Pod Autoscaler (HPA) Demo

**Description:** This demo shows how to automatically scale applications based on CPU usage using the Horizontal Pod Autoscaler.

- 🔄 PHP-Apache deployment that serves a simple web page
- ⚖️ HPA configuration to scale based on CPU utilization
- 🧪 Instructions for generating load to trigger scaling

**Features Demonstrated:**

- Horizontal Pod Autoscaler configuration
- Resource requests and limits
- CPU-based scaling policies
- Load testing and observing autoscaling behavior

### 3️⃣ ConfigMap and Secret Demo

**Description:** This demo illustrates how to manage application configuration and sensitive data using ConfigMaps and Secrets.

- ⚙️ ConfigMaps for non-sensitive configuration
- 🔒 Secrets for sensitive data
- 📄 Config and secrets exposed as environment variables
- 📁 Config and secrets mounted as files

**Features Demonstrated:**

- Creating and managing ConfigMaps and Secrets
- Injecting configuration via environment variables
- Mounting configuration data as files
- Best practices for configuration management

## 🚀 Usage

### Easy Deployment

Use the provided deployment script to deploy all demos at once or select specific ones:

```bash
# Deploy all demos to a Minikube cluster
./deploy-advanced-demos.sh minikube minikube-multinode all

# Deploy only the StatefulSet demo to a Kind cluster
./deploy-advanced-demos.sh kind kind-multi-node stateful

# Deploy only the HPA demo to a Minikube cluster
./deploy-advanced-demos.sh minikube minikube-multinode hpa

# Deploy only the ConfigMap and Secret demo
./deploy-advanced-demos.sh kind kind-multi-node config-secret
```

### Manual Deployment

You can also deploy the demos individually using kubectl:

```bash
# Deploy MongoDB StatefulSet demo
kubectl apply -f stateful-mongodb.yaml

# Deploy HPA demo
kubectl apply -f hpa-demo.yaml

# Deploy ConfigMap and Secret demo
kubectl apply -f configmap-secret-demo.yaml
```

## 🔍 Exploring the Demos

### MongoDB StatefulSet Demo

1. Check the StatefulSet and Pods:

   ```bash
   kubectl get statefulsets,pods -l app=mongodb
   ```

2. Access the Mongo Express UI:
   - If using Minikube: `minikube tunnel` then visit `http://localhost/mongo-express`
   - If using Kind: Visit `http://localhost/mongo-express`

3. Examine persistence:

   ```bash
   kubectl exec -it mongodb-0 -- mongo --eval "db.test.insert({name: 'demo'})"
   kubectl delete pod mongodb-0
   # Wait for pod to restart
   kubectl exec -it mongodb-0 -- mongo --eval "db.test.find()"
   ```

### HPA Demo

1. Monitor the HPA:

   ```bash
   kubectl get hpa php-apache --watch
   ```

2. Generate load to trigger scaling:

   ```bash
   kubectl run -i --tty load-generator --rm --image=busybox --restart=Never -- /bin/sh -c "while sleep 0.01; do wget -q -O- http://php-apache; done"
   ```

3. Observe the pods scaling:

   ```bash
   kubectl get pods -l run=php-apache
   ```

### ConfigMap and Secret Demo

1. Access the demo web interface:
   - Visit `http://localhost/config-demo`

2. Explore the mounted files:

   ```bash
   # Get the pod name
   POD=$(kubectl get pod -l app=configmap-secret-demo -o jsonpath='{.items[0].metadata.name}')
   
   # Exec into the pod
   kubectl exec -it $POD -- sh
   
   # List config files
   ls -la /usr/share/nginx/html/config
   
   # View a config value
   cat /usr/share/nginx/html/config/APP_ENV
   
   # List secret files
   ls -la /usr/share/nginx/html/secret
   
   # View a secret value
   cat /usr/share/nginx/html/secret/API_KEY
   ```

## 🧹 Cleanup

To remove all advanced demos:

```bash
kubectl delete -f stateful-mongodb.yaml
kubectl delete -f hpa-demo.yaml
kubectl delete -f configmap-secret-demo.yaml
```

Or to clean up everything at once:

```bash
kubectl delete statefulset,deployment,service,ingress,configmap,secret,pvc,pv -l app=mongodb
kubectl delete deployment,service,ingress,hpa php-apache
kubectl delete deployment,service,ingress,configmap,secret -l app=configmap-secret-demo
```
