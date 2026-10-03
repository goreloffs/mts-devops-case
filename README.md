# MTS DevOps Case

## Описание

Полный стек для демонстрационного веб-приложения Nginx в Kubernetes: развёртывание, доступ через Gateway API, мониторинг (Prometheus) и сбор логов (Fluent Bit).

## Архитектура

```
Пользователь
    ↓
Gateway API (Envoy Gateway)
    ↓
Service (nginx-svc)
    ↓
Pod Nginx  ←→  nginx-prometheus-exporter  ←  Prometheus
    ↓
Логи (stdout)  →  Fluent Bit  →  stdout (json_lines)
```

## Использованные технологии

| Компонент | Версия |
|---|---|
| Kubernetes | v1.31 (kind) |
| kind | v0.24.0 |
| Envoy Gateway | v1.0.2 (Gateway API) |
| Nginx | latest |
| nginx-prometheus-exporter | v1.1.0 |
| kube-prometheus-stack | latest (Helm) |
| Fluent Bit | v5.1.3 |
| helm | v4.1.4 |
| kubectl | v1.37.1 |
| ОС | Windows 10 + WSL 2 (Ubuntu) |

## Требования к среде

- Windows 10 с включённой виртуализацией
- WSL 2 + Ubuntu
- Docker Desktop (запущен, значок кита зелёный)
- kind, kubectl, helm (установлены через Chocolatey)

## Развёртывание

Одна команда:

```powershell
.\deploy.ps1
```

Или вручную по шагам:

1. Создать кластер: `kind create cluster --name mts-case`
2. Установить Envoy Gateway: `helm install eg oci://docker.io/envoyproxy/gateway-helm --version v1.0.2 -n envoy-gateway-system --create-namespace`
3. Применить GatewayClass: `kubectl apply -f gatewayclass.yaml`
4. Применить Nginx + exporter: `kubectl apply -f nginx-with-exporter.yaml`
5. Установить Prometheus: `helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring --create-namespace`
6. Применить ServiceMonitor: `kubectl apply -f servicemonitor.yaml`
7. Установить Fluent Bit: `helm install fluent-bit fluent/fluent-bit -n logging --create-namespace -f fluent-bit-values.yaml`

## Проверка работоспособности

### Проверка Gateway API

```powershell
kubectl get gatewayclass
kubectl get gateway
kubectl get httproute
kubectl get pods
```

### Проверка доступа к приложению

Первое окно PowerShell:

```powershell
kubectl port-forward -n envoy-gateway-system svc/envoy-default-my-gateway-1c7c06f0 8080:80
```

Второе окно PowerShell:

```powershell
curl.exe http://localhost:8080
```

Ожидаемый результат — HTML-страница «Welcome to nginx!».

### Проверка мониторинга

```powershell
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
```

Откройте в браузере `http://localhost:9090` и выполните запрос:

```
nginx_connections_active
```

Ожидаемый результат — числовое значение (например, `1`).

Дополнительно можно проверить `nginx_http_requests_total` — счётчик HTTP-запросов.

### Проверка логирования

После нескольких запросов `curl.exe http://localhost:8080` выполните:

```powershell
kubectl logs -n logging -l app.kubernetes.io/name=fluent-bit --tail=30
```

Ожидаемый результат — JSON-строки, содержащие access-логи Nginx, например:

```json
{"log":"10.244.0.8 - - [03/Oct/2026:16:28:22 +0000] \"GET / HTTP/1.1\" 200 896 \"-\" \"curl/8.9.1\""}
```

## Известные ограничения

- В кластере kind нет встроенного балансировщика нагрузки, поэтому Gateway имеет статус `PROGRAMMED: False` — это ожидаемое поведение. Доступ к приложению осуществляется через `kubectl port-forward`.
- Fluent Bit выводит логи в stdout (для локальной проверки). В продакшене их следовало бы отправлять в Elasticsearch/Loki.
- Решение протестировано на Windows 10 + WSL 2. На Ubuntu 24.04 должно работать без изменений, так как все компоненты кросс-платформенные.
