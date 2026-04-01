# Istio Service Mesh Demo

This demo demonstrates how to deploy and use Istio service mesh with a sample application using Helm.

## Features Demonstrated

- ✅ Istio installation via Helm
- ✅ Service mesh injection
- ✅ Traffic management (Virtual Services, Destination Rules)
- ✅ Security (mTLS, Authorization Policies)
- ✅ Observability (Kiali, Jaeger, Grafana)
- ✅ Circuit breaker patterns
- ✅ Canary deployments

## Prerequisites

- Kubernetes cluster (Kind/Minikube)
- Helm 3.x
- kubectl

## Quick Start

```bash
# Deploy Istio and sample applications
./deploy-istio.sh

# Access the applications
kubectl port-forward -n istio-system svc/istio-ingressgateway 8080:80

# Access Kiali dashboard
./access-kiali.sh

# Access Jaeger tracing
./access-jaeger.sh
```

## Sample Applications

### BookInfo Application
A polyglot microservices application that demonstrates:
- Multiple services with different languages (Python, Java, Ruby, Node.js)
- Inter-service communication
- Traffic routing and load balancing

### HTTPBin Service
A simple HTTP testing service for demonstrating:
- Circuit breaker patterns
- Retry policies
- Fault injection

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   ProductPage   │────│   Reviews v1    │────│    Ratings      │
│   (Python)      │    │   (Java)        │    │   (Node.js)     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │
         │              ┌─────────────────┐
         │              │   Reviews v2    │
         └──────────────│   (Java)        │
                        └─────────────────┘
                                 │
                        ┌─────────────────┐
                        │   Reviews v3    │
                        │   (Java)        │
                        └─────────────────┘
```

## Traffic Management Examples

- **Canary Deployment**: Route 10% traffic to v2, 90% to v1
- **Header-based Routing**: Route based on user headers
- **Fault Injection**: Inject delays and errors for testing

## Security Features

- **Automatic mTLS**: Secure service-to-service communication
- **Authorization Policies**: Fine-grained access control
- **Request Authentication**: JWT validation

## Observability

- **Kiali**: Service mesh topology and configuration
- **Jaeger**: Distributed tracing
- **Grafana**: Metrics and dashboards
- **Prometheus**: Metrics collection

## Cleanup

```bash
./cleanup-istio.sh
```
