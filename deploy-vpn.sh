#!/bin/bash

server_name=$(basename "$0")
chown -R nobody:nogroup /etc/openvpn
#Создадим файл vars, с настройками пользователя
sudo touch /usr/share/easy-rsa/vars

    #Значения переменных для vars


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


# Создание сертификата и ключа для сервера с указанным именем
./easyrsa gen-req $server_name nopass

# Путь к файлу dh.pem
dh_file="/usr/share/easy-rsa/pki/dh.pem"

# Проверяем, существует ли файл dh.pem
if [ -f "$dh_file" ]; then
    echo "Файл dh.pem уже существует."
else
    echo "Файла dh.pem не существует. Выполняем команду easyrsa gen-dh."
    ./easyrsa gen-dh
fi


cp /usr/share/easy-rsa/pki/private/$server_name.key /etc/openvpn/keys
chown nobody:nogroup /etc/openvpn/keys/$server_name.key
mv /usr/share/easy-rsa/pki/dh.pem /etc/openvpn/keys
chown nobody:nogroup /etc/openvpn/keys/dh.pem
#Получим настройки для файла server.conf 


echo "Сейчас соберем информацию для файла конфигурации сервера." 

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

#Добавление записи в server.conf
cat << EOF > /etc/openvpn/server/server.conf
dev tun
port $port_num
proto $protocol
ca /etc/openvpn/keys/ca.crt
cert /etc/openvpn/keys/$server_name.crt
key /etc/openvpn/keys/$server_name.key
crl-verify /etc/openvpn/keys/crl.pem
dh /etc/openvpn/keys/dh.pem
server 10.8.0.0 255.255.255.0
push "redirect-gateway def1"
push "dhcp-option DNS 8.8.8.8"
keepalive 10 120
status /var/log/openvpn/openvpn-status.log
log-append /var/log/openvpn/openvpn.log
persist-tun
persist-key
verb 4
daemon
mode server
user nobody
group nogroup
cipher AES-256-GCM
EOF

chown nobody:nogroup /etc/openvpn/server/server.conf
#Теперь создадим директорию и файлы для лог /var/log/openvpn
touch /var/log/openvpn/{openvpn-status,openvpn}.log; chown -R nobody:nogroup /var/log/openvpn

#Включаем движение трафика
echo net.ipv4.ip_forward=1 >>/etc/sysctl.conf
sysctl -p /etc/sysctl.conf

# Настройка NAT
actual_network_interface=$(ip -o -4 route show to default | awk '{print $5}')
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o $actual_network_interface -j MASQUERADE

#Настроим firewall

# Разрешим уже установленные и связанные соединения
iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A OUTPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

# Разрешим входящие и исходящие соединения для локального интерфейса и петли
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# Разрешим SSH-подключения
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 22 -j ACCEPT

# Добавляем правила iptables для Node Exporter, Prometheus, и OpenVPN Exporter
iptables -A INPUT -p tcp --dport 9100 -j ACCEPT # Node Exporter
iptables -A OUTPUT -p tcp --dport 9100 -j ACCEPT # Node Exporter

iptables -A INPUT -p tcp --dport 9090 -j ACCEPT # Prometheus
iptables -A OUTPUT -p tcp --dport 9090 -j ACCEPT # Prometheus

iptables -A INPUT -p tcp --dport 9176 -j ACCEPT # OpenVPN Exporter
iptables -A OUTPUT -p tcp --dport 9176 -j ACCEPT # OpenVPN Exporter


iptables -A INPUT -p $protocol --dport $port_num -j ACCEPT # VPN
iptables -A OUTPUT -p $protocol --dport $port_num -j ACCEPT # VPN

#TUN
iptables -A INPUT -i tun+ -j ACCEPT
iptables -A FORWARD -i tun+ -o $actual_network_interface -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i $actual_network_interface -o tun+ -m state --state RELATED,ESTABLISHED -j ACCEPT
# Закрываем все остальные входящие соединения
iptables -A INPUT -j DROP


# Сохраняем правила iptables
iptables-save > /etc/iptables/rules.v4

# Проверка успешности сохранения правил iptables
if [ $? -eq 0 ]; then
    echo "Настройка завершена. Правила iptables сохранены."
else
    echo "Ошибка при сохранении правил iptables."
fi

echo "Для создания VPN сервера отправьте файл $server_name.req на подпись в удостоверяющий центр.Затем сохраните файл $server_name.crt в директории /etc/openvpn/key "

echo " После запустите сервер VPN:  systemctl start openvpn-server@server"
                                                
