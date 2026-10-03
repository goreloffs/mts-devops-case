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
| Helm | v4.1.4 |
| kubectl | v1.37.1 |
| ОС | Windows 10 + WSL 2 (Ubuntu) |

## Требования к среде

- Windows 10 с включённой виртуализацией (или Ubuntu 24.04)
- WSL 2 + Ubuntu
- Docker Desktop (запущен, значок кита зелёный)
- kind, kubectl, helm (установлены)

## Развёртывание

**Важно:** PowerShell по умолчанию блокирует выполнение `.ps1`-скриптов. Перед запуском разрешите это один раз для текущей сессии:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

Затем перейдите в папку с файлами и запустите:

```powershell
cd C:\путь\к\mts-devops-case
.\deploy.ps1
```

Скрипт автоматически выполняет все шаги:

1. Создаёт kind-кластер `mts-case`
2. Устанавливает Envoy Gateway (Gateway API контроллер)
3. Создаёт GatewayClass `eg`
4. Применяет Gateway и HTTPRoute
5. Разворачивает Nginx с exporter
6. Устанавливает Prometheus (kube-prometheus-stack)
7. Подключает сбор метрик Nginx через ServiceMonitor
8. Устанавливает Fluent Bit для сбора логов

**Общее время развёртывания: 10–15 минут.**

## Проверка работоспособности

### Проверка Gateway API

```powershell
kubectl get gatewayclass
kubectl get gateway
kubectl get httproute
kubectl get pods
```

Ожидаемый результат:
- `eg` GatewayClass — `ACCEPTED: True`
- `my-gateway` — `PROGRAMMED: False` (это нормально для kind, см. раздел «Известные ограничения»)
- `nginx-route` — создан
- Pod nginx — `2/2 Running` (два контейнера: nginx + exporter)

### Проверка доступа к приложению

Окно 1 PowerShell:

```powershell
kubectl port-forward -n envoy-gateway-system svc/envoy-default-my-gateway-1c7c06f0 8080:80
```

Окно 2 PowerShell:

```powershell
curl.exe http://localhost:8080
```

Ожидаемый результат — HTML-страница `Welcome to nginx!`.

### Проверка мониторинга

```powershell
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
```

Откройте в браузере `http://localhost:9090`, введите запрос:

```
nginx_connections_active
```

Нажмите **Execute**. Ожидаемый результат — числовое значение (например, `1`).

Дополнительные метрики Nginx для проверки:
- `nginx_http_requests_total` — общее число HTTP-запросов
- `nginx_connections_reading` — активные чтения

### Проверка логирования

Сначала сделайте несколько HTTP-запросов (см. выше), затем выполните:

```powershell
kubectl logs -n logging -l app.kubernetes.io/name=fluent-bit --tail=30
```

Ожидаемый результат — JSON-строки с access-логами Nginx, например:

```json
{"log":"10.244.0.8 - - [03/Oct/2026:16:28:22 +0000] \"GET / HTTP/1.1\" 200 896 \"-\" \"curl/8.9.1\""}
```

Чтобы отфильтровать только HTTP-запросы:

```powershell
kubectl logs -n logging -l app.kubernetes.io/name=fluent-bit --tail=30 | Select-String "GET"
```

## Известные ограничения

- В кластере kind нет встроенного балансировщика нагрузки, поэтому Gateway имеет статус `PROGRAMMED: False` — это ожидаемое поведение. Доступ к приложению осуществляется через `kubectl port-forward`.
- Fluent Bit выводит логи в stdout. В продакшене логи следовало бы отправлять в Elasticsearch, Loki или аналогичное хранилище.
- Решение протестировано на Windows 10 + WSL 2. На Ubuntu 24.04 должно работать без изменений, так как все компоненты кросс-платформенные.

## Структура репозитория

```
mts-devops-case/
├── README.md                    # Этот файл
├── deploy.ps1                   # Скрипт автоматического развёртывания
├── gatewayclass.yaml            # GatewayClass для Envoy Gateway
├── app.yaml                     # Gateway + HTTPRoute
├── nginx-with-exporter.yaml     # Deployment Nginx + nginx-prometheus-exporter
├── servicemonitor.yaml          # Service + ServiceMonitor для Prometheus
└── fluent-bit-values.yaml       # Конфигурация Fluent Bit
```
