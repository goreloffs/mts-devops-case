# deploy.ps1 - automated deployment MTS DevOps Case

$ErrorActionPreference = "Continue"

Write-Host "=== 1. Creating kind cluster ==="
kind create cluster --name mts-case

Write-Host "=== 2. Installing Envoy Gateway ==="
helm install eg oci://docker.io/envoyproxy/gateway-helm --version v1.0.2 -n envoy-gateway-system --create-namespace

Write-Host "Waiting 30 seconds for controller..."
Start-Sleep -Seconds 30

Write-Host "=== 3. Creating GatewayClass ==="
kubectl apply -f gatewayclass.yaml

Write-Host "=== 4. Creating Gateway and HTTPRoute ==="
kubectl apply -f app.yaml

Write-Host "=== 5. Deploying Nginx + exporter ==="
kubectl apply -f nginx-with-exporter.yaml

Write-Host "=== 6. Installing Prometheus ==="
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring --create-namespace

Write-Host "=== 7. Configuring Nginx metrics ==="
kubectl apply -f servicemonitor.yaml

Write-Host "=== 8. Installing Fluent Bit ==="
helm repo add fluent https://fluent.github.io/helm-charts
helm repo update
helm install fluent-bit fluent/fluent-bit -n logging --create-namespace -f fluent-bit-values.yaml

Write-Host ""
Write-Host "=== Waiting 30 seconds ==="
Start-Sleep -Seconds 30

Write-Host "=== Status ==="
kubectl get gatewayclass
kubectl get gateway
kubectl get httproute
kubectl get pods
kubectl get pods -n monitoring
kubectl get pods -n logging

Write-Host ""
Write-Host "=== DONE ==="
Write-Host "Check app (2 windows):"
Write-Host "  1) kubectl port-forward -n envoy-gateway-system svc/envoy-default-my-gateway-1c7c06f0 8080:80"
Write-Host "  2) curl.exe http://localhost:8080"
Write-Host ""
Write-Host "Check Prometheus:"
Write-Host "  kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090"
Write-Host "  Open http://localhost:9090 and query nginx_connections_active"
Write-Host ""
Write-Host "Check logs:"
Write-Host "  kubectl logs -n logging -l app.kubernetes.io/name=fluent-bit --tail=30"
