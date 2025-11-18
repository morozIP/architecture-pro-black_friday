#!/bin/bash

# ===============================================
# Скрипт инициализации MongoDB Sharded Cluster
# Использует неинтерактивный режим для работы с mongosh.
# ===============================================

# -----------------------------------------------
# 1. Функция ожидания готовности контейнера
# -----------------------------------------------
wait_for_container() {
    CONTAINER_NAME=$1
    echo "🟡 Ожидание готовности контейнера $CONTAINER_NAME..."

    # Ждем, пока контейнер будет запущен и доступен (проверяем, что mongosh отвечает)
    until docker exec -i "$CONTAINER_NAME" mongosh --eval 'quit()' 2>/dev/null; do
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
cat <<EOF | docker exec -i configSrv mongosh
rs.initiate(
  {
    _id : "config_server",
    configsvr: true,
    members: [
      { _id : 0, host : "configSrv:27017" }
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

cat <<EOF | docker exec -i shard1-1 mongosh --port 27018
rs.initiate(
    {
      _id : "rs-shard1",
      members: [
        { _id : 0, host : "shard1-1:27018" },
        { _id : 1, host : "shard1-2:27021" },
        { _id : 2, host : "shard1-3:27022" }
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

cat <<EOF | docker exec -i shard2-1 mongosh --port 27019
rs.initiate(
    {
      _id : "rs-shard2",
      members: [
        { _id : 0, host : "shard2-1:27019" },
        { _id : 1, host : "shard2-2:27023" },
        { _id : 2, host : "shard2-3:27024" }
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

cat <<EOF | docker exec -i mongos_router mongosh --port 27020
// Добавление шардов
sh.addShard( "rs-shard1/shard1-1:27018");
sh.addShard( "rs-shard2/shard2-1:27019");

// Включение шардинга для базы данных
sh.enableSharding("somedb");

// Включение шардинга для коллекции (hashed sharding по полю name)
sh.shardCollection("somedb.helloDoc", { "name" : "hashed" } );

// Наполнение тестовыми данными
use somedb
// Используем insertOne, так как insert() устарел, и для асинхронной операции в цикле
for(var i = 0; i < 1000; i++) db.helloDoc.insertOne({age:i, name:"ly"+i})

var count = db.helloDoc.countDocuments();
print("Документов добавлено: " + count);

if (count === 1000) {
    print("🚀 Кластер успешно инициирован и протестирован!");
} else {
    print("💔 ОШИБКА: Добавлено неправильное количество документов: " + count);
}
db.helloDoc.getShardDistribution();
EOF

echo "✅ Инициализация кластера завершена."