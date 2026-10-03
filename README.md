# MTS DevOps Case

## Описание

Демонстрационное веб-приложение (Nginx), развёрнутое в Kubernetes и доступное через Gateway API.

## Архитектура

```
Пользователь → Gateway API (Envoy Gateway) → Service → Nginx Pod
```

## Использованные технологии

| Компонент | Версия |
|---|---|
| Kubernetes | v1.31 (kind) |
| kind | v0.24.0 |
| Envoy Gateway | v1.0.2 (Gateway API) |
| Nginx | latest |
| helm | v4.1.4 |
| kubectl | v1.37.1 |
| ОС | Windows 10 + WSL 2 (Ubuntu) |

## Требования к среде

- Windows 10 с включённой виртуализацией
- WSL 2 + Ubuntu
- Docker Desktop
- kind, kubectl, helm

## Развёртывание

Одна команда:

```powershell
.\deploy.ps1
```

Или вручную по шагам:

1. Создать кластер: `kind create cluster --name mts-case`
2. Установить Envoy Gateway: `helm install eg oci://docker.io/envoyproxy/gateway-helm --version v1.0.2 -n envoy-gateway-system --create-namespace`
3. Применить GatewayClass: `kubectl apply -f gatewayclass.yaml`
4. Применить приложение и Gateway: `kubectl apply -f app.yaml`

## Проверка работоспособности

### Проверка Gateway API

```powershell
kubectl get gatewayclass
kubectl get gateway
kubectl get httproute
```

### Проверка доступа к приложению

В первом окне PowerShell:

```powershell
kubectl port-forward -n envoy-gateway-system svc/envoy-default-my-gateway-1c7c06f0 8080:80
```

Во втором окне:

```powershell
curl.exe http://localhost:8080
```

Ожидаемый результат — HTML-страница «Welcome to nginx!».

## Известные ограничения

- В кластере kind нет встроенного балансировщика нагрузки, поэтому Gateway имеет статус `PROGRAMMED: False` — это ожидаемое поведение. Доступ к приложению осуществляется через `kubectl port-forward`.
- Мониторинг (Prometheus) и логирование (Fluentd/Filebeat) в текущей версии не реализованы.
