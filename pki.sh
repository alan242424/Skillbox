#!/bin/bash

echo "Укажите основные настройки создания сертификатов"


echo "Для каждого пункта есть настройки по умолчанию, их можно оставить"
echo "Страна(по умолчанию Russia):"; read country
if [[ -z $country ]]; then
   country="Russia"
fi
echo "Размер ключа(по умолчанию 2048):"; read key_size
if [[ $key_size =~ ^[0-9]+$ ]]; then #проверка на число
   echo "Установлен размер ключа:" $key_size
else
   key_size=2048; echo "Значение ключа установлено по умолчанию"
fi
echo "Укажите область(по умолчанию Kaliningrad"; read province
if [[ -z $province ]]; then
   province="Kaliningrad"
fi
echo "Город(по умолчанию Kaliningrad)"; read city
if [[ -z $city ]]; then
   city="Kalinigrad"
fi

echo "Организация (по умолчанию ooo)"; read org
if [[ -z $org ]]; then
   org="OOO"
fi

echo "email(по умолчанию alantsogoev24@gmail.com)"; read mail
if [[ -z $mail ]]; then
   mail="alantsogoev24@gmail.com"
fi

echo "срок действия сертификата, дней(по умолчанию 3650/10 лет): "; read expire
if [[ $expire =~ ^[0-9]+$ ]]; then
   echo "Срок действия сертификата" $expire "дней"
else
   expire=3650
fi

#file vars
touch /usr/share/easy-rsa/vars
sudo cat << EOF > /usr/share/easy-rsa/vars
set_var EASYRSA_REQ_COUNTRY $country
set_var EASYRSA_KEY_SIZE $key_size
set_var EASYRSA_REQ_PROVINCE $province
set_var EASYRSA_REQ_CITY $city
set_var EASYRSA_REQ_ORG $org
set_var EASYRSA_REQ_EMAIL $mail
set_var EASYRSA_CERT_EXPIRE $expire
EOF


# Переход в директорию PKI
cd /usr/share/easy-rsa

# Инициализация PKI (Public Key Infrastructure)
# Путь к директории pki
pki_dir="/usr/share/easy-rsa/pki"

# Проверяем, существует ли директория pki
if [ -d "$pki_dir" ]; then
    echo "Директория pki уже существует."
else
    echo "Директории pki не существует. Выполняем команду easyrsa init-pki."
    ./easyrsa init-pki
fi

# Генерация CA ключей и сертификата
./easyrsa build-ca

echo "CA и сертификаты успешно созданы."







