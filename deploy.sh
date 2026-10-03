#!/bin/bash
# deploy.sh - automated deployment MTS DevOps Case (Linux/Ubuntu)
# Deploys: kind cluster, Envoy Gateway, Nginx, Prometheus, Fluent Bit

set -e

echo "=== 1. Creating kind cluster ==="
kind create cluster --name mts-case

echo "=== 2. Installing Envoy Gateway ==="
helm install eg oci://docker.io/envoyproxy/gateway-helm --version v1.0.2 -n envoy-gateway-system --create-namespace

echo "Waiting 30 seconds for controller..."
sleep 30

echo "=== 3. Creating GatewayClass ==="
kubectl apply -f gatewayclass.yaml

echo "=== 4. Creating Gateway and HTTPRoute ==="
kubectl apply -f app.yaml

echo "=== 5. Deploying Nginx + exporter ==="
kubectl apply -f nginx-with-exporter.yaml

echo "=== 6. Installing Prometheus ==="
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
for i in 1 2 3; do
  helm repo update && break
  echo "Retry helm repo update ($i/3)..."
  sleep 5
done
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring --create-namespace

echo "=== 7. Configuring Nginx metrics ==="
kubectl apply -f servicemonitor.yaml

echo "=== 8. Installing Fluent Bit ==="
helm repo add fluent https://fluent.github.io/helm-charts || true
for i in 1 2 3; do
  helm repo update && break
  echo "Retry helm repo update ($i/3)..."
  sleep 5
done
helm install fluent-bit fluent/fluent-bit -n logging --create-namespace -f fluent-bit-values.yaml

echo ""
echo "=== Waiting 30 seconds ==="
sleep 30

echo "=== Status ==="
kubectl get gatewayclass
kubectl get gateway
kubectl get httproute
kubectl get pods
kubectl get pods -n monitoring
kubectl get pods -n logging

echo ""
echo "=== DONE ==="
echo "Check app (2 terminals):"
echo "  1) kubectl port-forward -n envoy-gateway-system svc/envoy-default-my-gateway-1c7c06f0 8080:80"
echo "  2) curl http://localhost:8080"
echo ""
echo "Check Prometheus:"
echo "  kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090"
echo "  Open http://localhost:9090 and query nginx_connections_active"
echo ""
echo "Check logs:"
echo "  kubectl logs -n logging -l app.kubernetes.io/name=fluent-bit --tail=30"
