#!/bin/bash

while true; do
    echo "Введите название сервера:"
    read server_name

    # Проверка наличия директории с таким именем
    if [ -d "/usr/share/easy-rsa/servers/$server_name" ]; then
        echo "Сервер с именем $server_name уже существует. Введите другое имя."
    else
        break
    fi
done
mkdir /usr/share/easy-rsa/servers/$server_name
# Создание структуры для deb пакет
cd $HOME
mkdir -p vpn-deploy-$server_name/DEBIAN
mkdir -p vpn-deploy-$server_name/usr/local/bin 
mkdir -p vpn-deploy-$server_name/etc/openvpn/keys
mkdir -p vpn-deploy-$server_name/etc/openvpn/server
cp /usr/share/easy-rsa/pki/ca.crt vpn-deploy-$server_name/etc/openvpn/keys/
cp /usr/share/easy-rsa/pki/crl.pem  vpn-deploy-$server_name/etc/openvpn/keys/
cp /usr/local/bin/deploy-vpn.sh vpn-deploy-$server_name/usr/local/bin/$server_name



touch vpn-deploy-$server_name/DEBIAN/control
cat <<EOF > vpn-deploy-$server_name/DEBIAN/control
Package: vpn-deploy
Version: 1.0
Section: custom
Priority: optional
Architecture: all
Depends: openvpn, easy-rsa, iptables, iptables-persistent
Maintainer: Alan <alantsogoev24@gmail.com>
Description: VPN server deploy
EOF
echo "Файл control создан в директории DEBIAN."

# Создание файла postinst
touch vpn-deploy-$server_name/DEBIAN/postinst
cat <<EOF > vpn-deploy-$server_name/DEBIAN/postinst
#!/bin/bash

# Запуск скрипта из /usr/local/bin
/usr/local/bin/$server_name

exit 0
EOF

# Делаем скрипт исполняемым
chmod +x vpn-deploy-$server_name/DEBIAN/postinst
echo "Файл postinst создан в директории DEBIAN."


#создание пакета
dpkg-deb --build vpn-deploy-$server_name

# Проверка на успешное создание пакета deb
if [ -f vpn-deploy-$server_name.deb ]; then
    echo "Пакет deb успешно создан: vpn-deploy.deb"
else
    echo "Ошибка при создании пакета deb."
fi

