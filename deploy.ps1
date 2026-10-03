# deploy.ps1 — автоматическое развёртывание решения MTS DevOps Case
Write-Host "=== 1. Создание кластера kind ==="
kind create cluster --name mts-case

Write-Host "=== 2. Установка Envoy Gateway (Gateway API) ==="
helm install eg oci://docker.io/envoyproxy/gateway-helm --version v1.0.2 -n envoy-gateway-system --create-namespace

Write-Host "Ожидание 30 секунд для запуска контроллера..."
Start-Sleep -Seconds 30

Write-Host "=== 3. Создание GatewayClass ==="
kubectl apply -f gatewayclass.yaml

Write-Host "=== 4. Развёртывание Nginx и Gateway ==="
kubectl apply -f app.yaml

Write-Host "=== 5. Ожидание готовности ==="
Start-Sleep -Seconds 20
kubectl get gatewayclass
kubectl get gateway
kubectl get httproute
kubectl get pods

Write-Host ""
Write-Host "=== ГОТОВО! ==="
Write-Host "Проверка доступа к приложению:"
Write-Host "  В первом окне:  kubectl port-forward -n envoy-gateway-system svc/envoy-default-my-gateway-1c7c06f0 8080:80"
Write-Host "  Во втором окне: curl.exe http://localhost:8080"