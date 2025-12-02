#!/bin/bash

# ===============================================
# Скрипт инициализации MongoDB Sharded Cluster
# Использует неинтерактивный режим для работы с mongosh.
# ===============================================

MONGO_SHELL="mongosh"
HOST_CONFIG="configSrv:27017"
HOST_SHARD1="shard1:27018"
HOST_SHARD2="shard2:27019"
HOST_ROUTER="mongos_router:27020"

DB_NAME="somedb"
COLLECTION_NAME="helloDoc"

# -----------------------------------------------
# 1. Функция ожидания готовности контейнера
# -----------------------------------------------
wait_for_container() {
    CONTAINER_NAME=$1
    echo "🟡 Ожидание готовности контейнера $CONTAINER_NAME..."

    # Ждем, пока контейнер будет запущен и доступен (проверяем, что mongosh отвечает)
    until docker exec -i "$CONTAINER_NAME" $MONGO_SHELL --eval 'quit()' 2>/dev/null; do
        printf '.'
        sleep 1
    done
    echo "🟢 Контейнер $CONTAINER_NAME доступен."
}

# -----------------------------------------------
# 2. Инициализация Config Server Replicaset
# -----------------------------------------------
echo ""
echo "==============================================="
echo "   1/4: Инициализация Config Server Replicaset  "
echo "==============================================="
wait_for_container configSrv

# Используем cat и pipe (|) для неинтерактивной передачи команд
cat <<EOF | docker exec -i configSrv $MONGO_SHELL --port 27017
rs.initiate(
  {
    _id : "config_server",
    configsvr: true,
    members: [
      { _id : 0, host : "$HOST_CONFIG" }
    ]
  },
  { force: true }
);
EOF
echo "✅ Config Server Replicaset 'config_server' инициирован."


# -----------------------------------------------
# 3. Инициализация Shard Replicasets
# -----------------------------------------------
echo ""
echo "============================================="
echo "   2/4: Инициализация Shard Replicaset 1     "
echo "============================================="
##wait_for_container shard1

cat <<EOF | docker exec -i shard1 $MONGO_SHELL --port 27018
rs.initiate(
    {
      _id : "shard1",
      members: [
        { _id : 0, host : "$HOST_SHARD1" }
      ]
    },
    { force: true }
);
EOF
echo "✅ Shard Replicaset 'shard1' инициирован."

echo ""
echo "============================================="
echo "   3/4: Инициализация Shard Replicaset 2     "
echo "============================================="
##wait_for_container shard2

cat <<EOF | docker exec -i shard2 $MONGO_SHELL --port 27019
rs.initiate(
    {
      _id : "shard2",
      members: [
        { _id : 0, host : "$HOST_SHARD2" }
      ]
    },
    { force: true }
);
EOF
echo "✅ Shard Replicaset 'shard2' инициирован."


# -----------------------------------------------
# 4. Настройка Router (mongos) и добавление шардов
# -----------------------------------------------
echo ""
echo "============================================="
echo "   4/4: Настройка Router и добавление шардов  "
echo "============================================="
##wait_for_container mongos_router

# Даем время на выборы Primary в Config Server и шардах
echo "🟡 Ожидание Primary в репликасетах (10 секунд)..."
sleep 10

cat <<EOF | docker exec -i mongos_router $MONGO_SHELL --port 27020
// Добавление шардов
sh.addShard( "shard1/$HOST_SHARD1");
sh.addShard( "shard2/$HOST_SHARD2");

// Включение шардинга для базы данных
sh.enableSharding("$DB_NAME");

// Включение шардинга для коллекции (hashed sharding по полю name)
sh.shardCollection("$DB_NAME.$COLLECTION_NAME", { "name" : "hashed" } );

// Наполнение тестовыми данными
use $DB_NAME
// Используем insertOne, так как insert() устарел, и для асинхронной операции в цикле
for(var i = 0; i < 1000; i++) db.$COLLECTION_NAME.insertOne({age:i, name:"ly"+i})

var count = db.$COLLECTION_NAME.countDocuments();
print("Документов добавлено: " + count);

if (count === 1000) {
    print("🚀 Кластер успешно инициирован и протестирован!");
} else {
    print("💔 ОШИБКА: Добавлено неправильное количество документов: " + count);
}
EOF

echo "✅ Инициализация кластера завершена."