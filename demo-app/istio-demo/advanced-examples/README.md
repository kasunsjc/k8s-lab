# Advanced Traffic Management Examples for Istio Demo

This directory contains advanced traffic management examples to demonstrate sophisticated Istio features.

## Fault Injection

Inject delays and errors to test application resilience:

```bash
kubectl apply -f fault-injection.yaml
```

## Timeout and Retry Policies

Configure timeouts and retry policies:

```bash
kubectl apply -f timeout-retry.yaml
```

## Rate Limiting

Implement rate limiting using Envoy filters:

```bash
kubectl apply -f rate-limiting.yaml
```

## Canary Deployments

Progressive traffic shifting for canary deployments:

```bash
# Start with 10% traffic to v2
kubectl apply -f canary-10-percent.yaml

# Increase to 50% traffic to v2
kubectl apply -f canary-50-percent.yaml

# Complete migration to v2
kubectl apply -f canary-100-percent.yaml
```

## A/B Testing

Header-based routing for A/B testing:

```bash
kubectl apply -f ab-testing.yaml
```

## Circuit Breaker

Circuit breaker patterns with outlier detection:

```bash
kubectl apply -f circuit-breaker.yaml
```
