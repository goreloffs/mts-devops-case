# MTS DevOps Case

## Описание

Полный стек для демонстрационного веб-приложения Nginx в Kubernetes: развёртывание, доступ через Gateway API, мониторинг (Prometheus) и сбор логов (Fluent Bit). Решение кроссплатформенное — работает на Windows (PowerShell) и на Linux (Bash).

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
| Fluent Bit | v5.x |
| Helm | v3.22 / v4.1 |
| kubectl | v1.37.1 |

## Проверенные ОС

| ОС | Скрипт | Статус |
|---|---|---|
| Windows 10 + WSL 2 (Ubuntu) | `deploy.ps1` | ✅ Проверено |
| Ubuntu 26.04 LTS (WSL 2) | `deploy.sh` | ✅ Проверено |

На Ubuntu 24.04 LTS также должно работать без изменений — все компоненты (Docker, kind, kubectl, helm, Envoy Gateway, kube-prometheus-stack, Fluent Bit) официально поддерживают эту версию.

## Требования к среде

- **Windows:** Windows 10+, WSL 2 + Ubuntu, Docker Desktop (запущен), kind, kubectl, helm
- **Ubuntu:** Docker Engine, kind, kubectl, helm

## Развёртывание

### Вариант 1. Windows (PowerShell)

Разрешить выполнение скриптов (один раз для сессии):

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

Перейти в папку проекта и запустить:

```powershell
cd C:\путь\к\mts-devops-case
.\deploy.ps1
```

### Вариант 2. Ubuntu / Linux (Bash)

Перейти в папку проекта и запустить:

```bash
cd путь/к/mts-devops-case
chmod +x deploy.sh
./deploy.sh
```

**Общее время развёртывания: 10–15 минут.**

Скрипт автоматически выполняет:

1. Создаёт kind-кластер `mts-case`
2. Устанавливает Envoy Gateway (Gateway API контроллер)
3. Создаёт GatewayClass `eg`
4. Применяет Gateway и HTTPRoute
5. Разворачивает Nginx с exporter
6. Устанавливает Prometheus (kube-prometheus-stack)
7. Подключает сбор метрик Nginx через ServiceMonitor
8. Устанавливает Fluent Bit для сбора логов

## Проверка работоспособности

### Проверка Gateway API

```bash
kubectl get gatewayclass
kubectl get gateway
kubectl get httproute
kubectl get pods
```

Ожидаемый результат:
- `eg` GatewayClass — `ACCEPTED: True`
- `my-gateway` — `PROGRAMMED: False` (нормально для kind, см. раздел «Известные ограничения»)
- `nginx-route` — создан
- Pod nginx — `2/2 Running` (два контейнера: nginx + exporter)

### Проверка доступа к приложению

Терминал 1:

```bash
kubectl port-forward -n envoy-gateway-system svc/envoy-default-my-gateway-1c7c06f0 8080:80
```

Терминал 2:

```bash
curl http://localhost:8080
```

Ожидаемый результат — HTML-страница `Welcome to nginx!`.

### Проверка мониторинга

```bash
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
```

Откройте в браузере `http://localhost:9090`, введите запрос:

```
nginx_connections_active
```

Нажмите **Execute**. Ожидаемый результат — числовое значение (например, `1`).

Дополнительные метрики Nginx:
- `nginx_http_requests_total` — общее число HTTP-запросов
- `nginx_connections_reading` — активные чтения

### Проверка логирования

Сначала сделайте несколько HTTP-запросов (см. выше), затем:

```bash
kubectl logs -n logging -l app.kubernetes.io/name=fluent-bit --tail=30
```

Ожидаемый результат — JSON-строки с access-логами Nginx:

```json
{"log":"10.244.0.8 - - [03/Oct/2026:16:28:22 +0000] \"GET / HTTP/1.1\" 200 896 \"-\" \"curl/8.9.1\""}
```

Отфильтровать только HTTP-запросы:

```bash
kubectl logs -n logging -l app.kubernetes.io/name=fluent-bit --tail=30 | grep GET
```

## Известные ограничения

- В кластере kind нет встроенного балансировщика нагрузки, поэтому Gateway имеет статус `PROGRAMMED: False` — это ожидаемое поведение. Доступ к приложению осуществляется через `kubectl port-forward`.
- Fluent Bit выводит логи в stdout. В продакшене логи следовало бы отправлять в Elasticsearch, Loki или аналогичное хранилище.
- На Windows при запуске `.ps1` требуется один раз разрешить выполнение скриптов через `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass`.

## Структура репозитория

```
mts-devops-case/
├── README.md                    # Этот файл
├── deploy.ps1                   # Автоматизация для Windows (PowerShell)
├── deploy.sh                    # Автоматизация для Linux (Bash)
├── gatewayclass.yaml            # GatewayClass для Envoy Gateway
├── app.yaml                     # Gateway + HTTPRoute
├── nginx-with-exporter.yaml     # Deployment Nginx + nginx-prometheus-exporter
├── servicemonitor.yaml          # Service + ServiceMonitor для Prometheus
└── fluent-bit-values.yaml       # Конфигурация Fluent Bit
```
