#!/bin/bash

# ===============================================
# Скрипт инициализации MongoDB Sharded Cluster
# Запускается внутри контейнера 'configurator'.
# ===============================================

MONGO_SHELL="mongosh"
HOST_CONFIG="configSrv:27017"

HOST_SHARD1_1="shard1-1:27018"
HOST_SHARD1_2="shard1-2:27021"
HOST_SHARD1_3="shard1-3:27022"

HOST_SHARD2_1="shard2-1:27019"
HOST_SHARD2_2="shard2-2:27023"
HOST_SHARD2_3="shard2-3:27024"

HOST_ROUTER="mongos_router:27020"

DB_NAME="somedb"
COLLECTION_NAME="helloDoc"
CONFIG_RS_NAME="config_server"
SHARD1_RS_NAME="rs-shard1"
SHARD2_RS_NAME="rs-shard2"

# -----------------------------------------------
# 1. Функция ожидания готовности сервиса
# -----------------------------------------------
wait_for_service() {
    SERVICE_HOST=$1
    echo "🟡 Ожидание готовности сервиса $SERVICE_HOST..."

    # Пробуем подключиться, пока mongosh не вернет успешный код
    until $MONGO_SHELL --host "$SERVICE_HOST" --eval 'quit()' 2>/dev/null; do
        printf '.'
        sleep 1
    done
    echo "🟢 Сервис $SERVICE_HOST доступен."
}

# -----------------------------------------------
# 2. Инициализация Config Server Replicaset
# -----------------------------------------------
echo ""
echo "==============================================="
echo "   1/4: Инициализация Config Server Replicaset  "
echo "==============================================="
wait_for_service "$HOST_CONFIG"

# Используем прямой вызов $MONGO_SHELL --host "$HOST_CONFIG"
cat <<EOF | $MONGO_SHELL --host "$HOST_CONFIG"
rs.initiate(
  {
    _id : "$CONFIG_RS_NAME",
    configsvr: true,
    members: [
      { _id : 0, host : "$HOST_CONFIG" }
    ]
  },
  { force: true }
);
EOF
echo "✅ Config Server Replicaset '$CONFIG_RS_NAME' инициирован."

# -----------------------------------------------
# 3. Инициализация Shard Replicasets
# -----------------------------------------------
echo ""
echo "============================================="
echo "   2/4: Инициализация Shard Replicaset 1     "
echo "============================================="
wait_for_service "$HOST_SHARD1_1"

cat <<EOF | $MONGO_SHELL --host "$HOST_SHARD1_1"
rs.initiate(
    {
      _id : "$SHARD1_RS_NAME",
      members: [
        { _id : 0, host : "$HOST_SHARD1_1" },
        { _id : 1, host : "$HOST_SHARD1_2" },
        { _id : 2, host : "$HOST_SHARD1_3" }
      ]
    },
    { force: true }
);
EOF
echo "✅ Shard Replicaset '$SHARD1_RS_NAME' инициирован."

echo ""
echo "============================================="
echo "   3/4: Инициализация Shard Replicaset 2     "
echo "============================================="
wait_for_service "$HOST_SHARD2_1"

cat <<EOF | $MONGO_SHELL --host "$HOST_SHARD2_1"
rs.initiate(
    {
      _id : "$SHARD2_RS_NAME",
      members: [
        { _id : 0, host : "$HOST_SHARD2_1" },
        { _id : 1, host : "$HOST_SHARD2_2" },
        { _id : 2, host : "$HOST_SHARD2_3" }
      ]
    },
    { force: true }
);
EOF
echo "✅ Shard Replicaset '$SHARD2_RS_NAME' инициирован."

# -----------------------------------------------
# 4. Настройка Router (mongos) и добавление шардов
# -----------------------------------------------
echo ""
echo "============================================="
echo "   4/4: Настройка Router и добавление шардов  "
echo "============================================="
wait_for_service "$HOST_ROUTER"

# Даем время на выборы Primary в Config Server и шардах
echo "🟡 Ожидание Primary в репликасетах (10 секунд)..."
sleep 10

cat <<EOF | $MONGO_SHELL --host "$HOST_ROUTER"
// Добавление шардов
sh.addShard( "$SHARD1_RS_NAME/$HOST_SHARD1_1");
sh.addShard( "$SHARD2_RS_NAME/$HOST_SHARD2_1");

// Включение шардинга для базы данных
sh.enableSharding("$DB_NAME");

// Включение шардинга для коллекции (hashed sharding по полю name)
sh.shardCollection("$DB_NAME.$COLLECTION_NAME", { "name" : "hashed" } );

// Наполнение тестовыми данными
use $DB_NAME
for(var i = 0; i < 1000; i++) db.$COLLECTION_NAME.insertOne({age:i, name:"ly"+i})

var count = db.$COLLECTION_NAME.countDocuments();
print("Документов добавлено: " + count);

if (count === 1000) {
    print("🚀 Кластер успешно инициирован и протестирован!");
} else {
    print("💔 ОШИБКА: Добавлено неправильное количество документов: " + count);
}
// Финальная проверка распределения данных
db.$COLLECTION_NAME.getShardDistribution();
EOF

echo "✅ Инициализация кластера завершена."