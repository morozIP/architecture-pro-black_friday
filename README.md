# Инструкция по запуску

Этот сценарий разворачивает комплексную архитектуру, включающую:
*   **MongoDB Sharded Cluster**: Config Server (ReplicaSet), 2 Шарда (по 3 узла ReplicaSet в каждом), Mongos Router.
*   **Redis Cluster**: 6 узлов.
*   **API Application**: Python приложение для работы с данными.
*   **Configurators**: Автоматические скрипты инициализации кластеров базы и кэша.

## Запуск проекта

### Старт контейнеров
Используем флаг `--build` для сборки локальных образов (API и конфигураторов) и `-d` для запуска в фоновом режиме.
```bash
docker-compose -f "4 sharding-repl-cache/sharding-repl-cache-docker-compose.yaml" up --build -d
```

### Проверка статуса инициализации
Так как кластеры MongoDB и Redis требуют настройки после старта контейнеров, в проекте есть специальные контейнеры-конфигураторы. Убедитесь, что они отработали успешно:

**Проверка MongoDB:**
```bash
docker logs mongo-configurator
```
*Ожидаемый результат в конце лога:* `Кластер успешно инициирован и протестирован!`

**Проверка Redis:**
```bash
docker logs redis-configurator
```

**Курлим как мужчины**
в винде баш терминал юзать
```bash
curl -X 'GET' 'http://localhost:8080/' -H 'accept: application/json'
```

### Удаляем все следы присутствия
```bash
docker-compose -f "4 sharding-repl-cache/sharding-repl-cache-docker-compose.yaml" down -v --rmi all --remove-orphans
```
