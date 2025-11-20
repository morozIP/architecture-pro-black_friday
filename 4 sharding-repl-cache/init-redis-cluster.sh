#!/bin/bash

# ===============================================
# Скрипт инициализации кластера Redis
# Запускается внутри контейнера 'redis-configurator'.
# ===============================================

REDIS_NODES="redis_1:6379 redis_2:6379 redis_3:6379 redis_4:6379 redis_5:6379 redis_6:6379"

echo "🟡 Ожидание готовности всех узлов Redis..."

# Функция ожидания готовности всех узлов Redis
wait_for_redis_nodes() {
    for host_port in $REDIS_NODES; do
        host=${host_port%:*}
        port=${host_port#*:}
        until redis-cli -h "$host" -p "$port" ping 2>/dev/null | grep -q PONG; do
            printf '.'
            sleep 1
        done
        echo "🟢 Узел Redis $host_port доступен."
    done
}

wait_for_redis_nodes

echo ""
echo "==============================================="
echo "   Инициализация кластера Redis (3 мастера, 3 реплики) "
echo "==============================================="

# Проверяем, не был ли кластер уже создан
# Если команда cluster info не выполняется успешно, значит, кластер еще не настроен
redis-cli -h redis_1 -p 6379

echo "yes" | redis-cli --cluster create $REDIS_NODES --cluster-replicas 1

# Успешное завершение скрипта
exit 0