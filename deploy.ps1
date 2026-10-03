# deploy.ps1 — автоматическое развёртывание решения MTS DevOps Case
# Разворачивает: kind-кластер, Envoy Gateway, Nginx, Prometheus, Fluent Bit

$ErrorActionPreference = "Continue"

Write-Host "=== 1. Создание кластера kind ==="
kind create cluster --name mts-case

Write-Host "=== 2. Установка Envoy Gateway (Gateway API) ==="
helm repo add envoy-gateway https://gateway.envoyproxy.io/helm 2>$null
helm install eg oci://docker.io/envoyproxy/gateway-helm --version v1.0.2 -n envoy-gateway-system --create-namespace

Write-Host "Ожидание 30 секунд для запуска контроллера..."
Start-Sleep -Seconds 30

Write-Host "=== 3. Создание GatewayClass ==="
kubectl apply -f gatewayclass.yaml

Write-Host "=== 4. Развёртывание Nginx + nginx-exporter ==="
kubectl apply -f nginx-with-exporter.yaml

Write-Host "=== 5. Установка Prometheus (kube-prometheus-stack) ==="
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring --create-namespace

Write-Host "=== 6. Настройка сбора метрик Nginx ==="
kubectl apply -f servicemonitor.yaml

Write-Host "=== 7. Установка Fluent Bit для сбора логов ==="
helm repo add fluent https://fluent.github.io/helm-charts
helm repo update
helm install fluent-bit fluent/fluent-bit -n logging --create-namespace -f fluent-bit-values.yaml

Write-Host ""
Write-Host "=== Ожидание готовности 30 секунд ==="
Start-Sleep -Seconds 30

Write-Host "=== Проверка состояния ==="
kubectl get gatewayclass
kubectl get gateway
kubectl get httproute
kubectl get pods
kubectl get pods -n monitoring
kubectl get pods -n logging

Write-Host ""
Write-Host "=== ГОТОВО! ==="
Write-Host "Проверка доступа к приложению (2 окна PowerShell):"
Write-Host "  1) kubectl port-forward -n envoy-gateway-system svc/envoy-default-my-gateway-1c7c06f0 8080:80"
Write-Host "  2) curl.exe http://localhost:8080"
Write-Host ""
Write-Host "Проверка мониторинга:"
Write-Host "  kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090"
Write-Host "  Открыть в браузере http://localhost:9090 и ввести запрос nginx_connections_active"
Write-Host ""
Write-Host "Проверка логирования:"
Write-Host "  kubectl logs -n logging -l app.kubernetes.io/name=fluent-bit --tail=30"