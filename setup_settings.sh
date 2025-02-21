#!/bin/bash


# Проверка наличия необходимых пакетов
check_package() {
    local package=$1
    if ! dpkg -l | grep -q "^ii  $package "; then
        echo "Пакет '$package' не установлен. Установка..."
        if ! sudo apt-get install -y "$package"; then
            echo "Не удалось установить пакет '$package'."
        fi
    else
        echo "Пакет '$package' уже установлен."
    fi
}

# Параметры конфигурации
EASYRSA_CONFIG_FILE="/home/yc-user/ServerSettings/easy_rsa_config.conf"  # Путь к файлу конфигурации Easy-RSA по умолчанию

# Проверка установленных пакетов
check_package "ufw"
check_package "easy-rsa"

# 1. Закрытие фаерволом ненужных портов (UFW)
echo "Настройка брандмауэра UFW..."

# Включение UFW, если он еще не включен
if ! sudo ufw status | grep -q "Status: active"; then
    echo "Включение UFW..."
    if ! sudo ufw enable; then
        echo "Не удалось включить UFW."
    fi
else
    echo "UFW уже включен."
fi

# Установка политики по умолчанию, если она еще не установлена
if ! sudo ufw status | grep -q "Default: deny (incoming)"; then
    echo "Установка политики UFW по умолчанию: deny incoming..."
    if ! sudo ufw default deny incoming; then
        echo "Не удалось установить политику UFW по умолчанию."
    fi
else
    echo "Политика UFW по умолчанию уже установлена: deny incoming."
fi

# Функция для разрешения порта, если он еще не разрешен
allow_port() {
    local port=$1
    local protocol=${2:-tcp} # По умолчанию TCP
    if ! sudo ufw status | grep -q "${port}/${protocol}"; then
        echo "Разрешение порта $port/$protocol..."
        if ! sudo ufw allow "${port}/${protocol}"; then
            echo "Предупреждение: Не удалось разрешить порт $port/$protocol."
        fi
    else
        echo "Порт $port/$protocol уже разрешен."
    fi
}

# Разрешение необходимых портов
allow_port 22
allow_port 80
allow_port 443

# 2. Настройка удостоверяющего центра Easy-RSA
echo "Настройка удостоверяющего центра Easy-RSA..."

# Проверка существования файла конфигурации Easy-RSA
if [ ! -f "$EASYRSA_CONFIG_FILE" ]; then
    echo "Файл конфигурации Easy-RSA не найден: $EASYRSA_CONFIG_FILE"
    exit 1
fi

# Чтение настроек из файла конфигурации
if ! source "$EASYRSA_CONFIG_FILE"; then
    echo "Не удалось загрузить файл конфигурации Easy-RSA: $EASYRSA_CONFIG_FILE"
    exit 1
fi

# Создание рабочей директории Easy-RSA, если она не существует
EASYRSA_BASEDIR="${EASYRSA_BASEDIR:-$HOME/easy-rsa}" # Путь к директории Easy-RSA по умолчанию

if [ ! -d "$EASYRSA_BASEDIR" ]; then
    echo "Создание директории Easy-RSA: $EASYRSA_BASEDIR..."
    mkdir -p "$EASYRSA_BASEDIR"
    if [ ! -d "$EASYRSA_BASEDIR" ]; then
        echo "Не удалось создать директорию Easy-RSA: $EASYRSA_BASEDIR"
        exit 1
    fi

    # Копирование файлов Easy-RSA в рабочую директорию, если это необходимо.
    echo "Копирование файлов Easy-RSA..."
    cp -r /usr/share/easy-rsa/* "$EASYRSA_BASEDIR"  

fi

chmod -R 700 "$EASYRSA_BASEDIR" 
# Инициализация PKI, если она еще не выполнена
if [ ! -f "$EASYRSA_BASEDIR/pki/ca.crt" ]; then
    echo "Инициализация PKI..."
    cd "$EASYRSA_BASEDIR" 
    ./easyrsa init-pki
else
    echo "PKI уже инициализирована."
fi

# 3. Создание корневого сертификата для центра, если он еще не создан.
if [ ! -f "$EASYRSA_BASEDIR/pki/ca.crt" ]; then
    echo "Создание корневого сертификата..."
    ./easyrsa build-ca  
    echo "Корневой сертификат создан."
else
    echo "Корневой сертификат уже существует."
fi

echo "Настройка удостоверяющего центра Easy-RSA завершена."

echo "Настройка сервера завершена."
exit 0
