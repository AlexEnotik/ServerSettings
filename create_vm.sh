#!/bin/bash

# --- Основные настройки (ОБЯЗАТЕЛЬНО ПРОВЕРИТЬ!) ---
ZONE="ru-central1-a"          # Зона доступности
NETWORK_NAME="ca-cert-net"    # Имя сети
SUBNET_NAME="ca-cert-subnet"  # Имя подсети
DISK_SIZE="20"               # Размер диска в GB
USERNAME="ubuntu"             # Имя пользователя для SSH
SSH_KEY=$(cat ~/.ssh/id_rsa.pub) # Публичный SSH ключ (из ~/.ssh/id_rsa.pub)
INSTANCE_NAME="ca-cert"       # Имя ВМ
IMAGE_ID="fd893iiqs74r6om1hqa8"  # ID образа

# --- Проверка и создание сети (если не существует) ---
NETWORK_ID=$(yc vpc network list --format json 2>/dev/null | jq -r '.[] | select(.name == "'"$NETWORK_NAME"'") | .id')
NETWORK_ID=${NETWORK_ID:-""} # Ensure NETWORK_ID is empty string if jq returns nothing

if [ $? -ne 0 ]; then
  echo "Ошибка: не удалось получить список сетей."
  exit 1
fi
if [ -z "$NETWORK_ID" ]; then
  echo "Сеть '$NETWORK_NAME' не найдена. Создаем ее..."
  yc vpc network create --name "$NETWORK_NAME" --format json 2>/dev/null | jq -r '.id'
  if [ $? -ne 0 ]; then
    echo "Ошибка: не удалось создать сеть '$NETWORK_NAME'."
    exit 1
  fi
  NETWORK_ID=$(yc vpc network list --format json 2>/dev/null | jq -r '.[] | select(.name == "'"$NETWORK_NAME"'") | .id') # Get network id again after creation
  NETWORK_ID=${NETWORK_ID:-""}
  echo "Сеть '$NETWORK_NAME' создана с ID: $NETWORK_ID"
else
  echo "Сеть '$NETWORK_NAME' найдена с ID: $NETWORK_ID"
fi

# --- Проверка и создание подсети (если не существует) ---
SUBNET_ID=$(yc vpc subnet list --format json 2>/dev/null | jq -r '.[] | select(.name == "'"$SUBNET_NAME"'" and .network_id == "'"$NETWORK_ID"'") | .id')
SUBNET_ID=${SUBNET_ID:-""} # Ensure SUBNET_ID is an empty string if jq returns nothing

if [ $? -ne 0 ]; then
  echo "Ошибка: не удалось получить список подсетей."
  exit 1
fi
if [ -z "$SUBNET_ID" ]; then
  echo "Подсеть '$SUBNET_NAME' не найдена. Создаем ее..."
  yc vpc subnet create --name "$SUBNET_NAME" --zone "$ZONE" --network-id "$NETWORK_ID" --range "10.128.0.0/20" --format json 2>/dev/null | jq -r '.id'
  if [ $? -ne 0 ]; then
    echo "Ошибка: не удалось создать подсеть '$SUBNET_NAME'."
    exit 1
  fi
  SUBNET_ID=$(yc vpc subnet list --format json 2>/dev/null  | jq -r '.[] | select(.name == "'"$SUBNET_NAME"'") | .id') # Get subnet ID again after creation
  SUBNET_ID=${SUBNET_ID:-""}
  echo "Подсеть '$SUBNET_NAME' создана с ID: $SUBNET_ID"
else
  echo "Подсеть '$SUBNET_NAME' найдена с ID: $SUBNET_ID"
fi

# --- Проверка и создание ВМ (если не существует) ---
INSTANCE_ID=$(yc compute instance list --zone "$ZONE" --format json 2>/dev/null | jq -r '.[] | select(.name == "'"$INSTANCE_NAME"'") | .id')
INSTANCE_ID=${INSTANCE_ID:-""} # Ensure INSTANCE_ID is an empty string if jq returns nothing

if [ $? -ne 0 ]; then
  echo "Ошибка: не удалось получить список ВМ."
  exit 1
fi

if [ -z "$INSTANCE_ID" ]; then
  echo "ВМ '$INSTANCE_NAME' не найдена. Создаем ее..."
  yc compute instance create --name "$INSTANCE_NAME" --zone "$ZONE" --create-boot-disk image-id="$IMAGE_ID",size="$DISK_SIZE" --network-interface subnet-id="$SUBNET_ID" --metadata ssh-keys="$USERNAME:$SSH_KEY"
  if [ $? -ne 0 ]; then
    echo "Ошибка: не удалось создать ВМ '$INSTANCE_NAME'."
    exit 1
  fi
  echo "Запрос на создание ВМ отправлен.  Проверьте Yandex Cloud Console."
else
  echo "ВМ '$INSTANCE_NAME' уже существует с ID: $INSTANCE_ID"
fi

# --- Важные замечания ---
# * Убедитесь, что yc cli настроен и аутентифицирован.
# * Проверьте группы безопасности для SSH доступа (порт 22).
# * Убедитесь, что IMAGE_ID существует и доступен.
# * CIDR подсети (10.128.0.0/20) не должен пересекаться с другими подсетями.
# * Рассмотрите использование Terraform для более сложной инфраструктуры.
