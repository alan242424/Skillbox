#!/bin/bash
client_name=$(basename "$0")

#Начнем создавать клиента 
echo "IP к которому необходимо подключаться клиентам"; read ip_adress 
echo "Порт(по умолчанию 1194):"; read port_num
if [[ $port_num =~ ^[0-9]+$ ]]; then
   echo "Установлен порт:" $port_num 
else
   port_num=1194; echo "Номер порта установлен по умолчанию" 
echo "Протокол(по умолчанию udp)для установки tcp введите 1"; read protocol
fi
if [[ $protocol -eq 1 ]]; then
   protocol="tcp"
   echo "Выбран протокол tcp" 
else
   protocol="udp"
   echo "Выбран протокол udp"
fi


#Создадим темповый файл конфигурации клиента с настройками 
touch /var/log/openvpn/client.log
touch /etc/openvpn/client/client.conf 
cat << EOF > /etc/openvpn/client.conf 
client 
dev tun 
proto $protocol 
remote $ip_adress $port_num 
nobind
persist-key
persist-tun
ca /etc/openvpn/keys/ca.crt
cert /etc/openvpn/keys/$client_name.crt
key /etc/openvpn/keys/$client_name.key
crl-verify /etc/openvpn/keys/crl.pem
dh /etc/openvpn/keys/dh.pem
log /var/log/openvpn/client.log
verb 4
mute 10
cipher AES-256-GCM
EOF

#Создание клиента
cd /usr/share/easy-rsa 


# Путь к директории pki
pki_dir="/usr/share/easy-rsa/pki"

# Проверяем, существует ли директория pki
if [ -d "$pki_dir" ]; then
    echo "Директория pki уже существует."
else
    echo "Директории pki не существует. Выполняем команду easyrsa init-pki."
    ./easyrsa init-pki

fi

./easyrsa gen-req "$client_name" nopass 

# Путь к файлу dh.pem
dh_file="/usr/share/easy-rsa/pki/dh.pem"

# Проверяем, существует ли файл dh.pem
if [ -f "$dh_file" ]; then
    echo "Файл dh.pem уже существует."
else
    echo "Файла dh.pem не существует. Выполняем команду easyrsa gen-dh."
    ./easyrsa gen-dh
fi

cp /usr/share/easy-rsa/pki/private/$client_name.key /etc/openvpn/keys
mv /usr/share/easy-rsa/pki/dh.pem /etc/openvpn/keys

echo "Для подключения к серверу VPN необходимо подписать в удостоверяющем центре ваш $client_name.req находящийся в директории /usr/share/easy-rsa/pki/reqs"

echo  "После подписания вашего файла $clien_name.req отправьте файл в директорию /etc/openvpn/keys : sudo systemctl start openvpn-client@client"
