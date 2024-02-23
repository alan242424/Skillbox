#!/bin/bash

while true; do
    echo "Введите название клиента:"
    read client_name

    # Проверка наличия директории с таким именем
    if [ -d "/usr/share/easy-rsa/clients/$client_name" ]; then
        echo "клиент с именем $client_name уже существует. Введите другое имя."
    else
        break
    fi
done
mkdir /usr/share/easy-rsa/clients/$client_name
# Создание структуры для deb пакет
cd $HOME
mkdir -p client-vpn-$client_name/DEBIAN
mkdir -p client-vpn-$client_name/usr/local/bin
mkdir  client-vpn-$client_name/usr/local/bin/ovpn
mkdir -p client-vpn-$client_name/etc/openvpn/keys
mkdir -p client-vpn-$client_name/etc/openvpn/client
cp /usr/share/easy-rsa/pki/ca.crt client-vpn-$client_name/etc/openvpn/keys/
cp /usr/share/easy-rsa/pki/crl.pem  client-vpn-$client_name/etc/openvpn/keys/
cp /usr/local/bin/client-make.sh client-vpn-$client_name/usr/local/bin/$client_name
cp /usr/local/bin/ovpn.sh client-vpn-$client_name/usr/local/bin/ovpn/$client_name
touch client-vpn-$client_name/DEBIAN/control
cat <<EOF > client-vpn-$client_name/DEBIAN/control
Package: client-vpn
Version: 1.0
Section: custom
Priority: optional
Architecture: all
Depends: openvpn, easy-rsa
Maintainer: Alan <alantsogoev24@gmail.com>
Description: client-vpn deploy
EOF
echo "Файл control создан в директории DEBIAN."

# Создание файла postinst
touch client-vpn-$client_name/DEBIAN/postinst
cat <<EOF > client-vpn-$client_name/DEBIAN/postinst
#!/bin/bash

# Запуск скрипта из /usr/local/bin
/usr/local/bin/$client_name

exit 0
EOF

# Делаем скрипт исполняемым
chmod +x client-vpn-$client_name/DEBIAN/postinst
echo "Файл postinst создан в директории DEBIAN."


#создание пакета
dpkg-deb --build client-vpn-$client_name

# Проверка на успешное создание пакета deb
if [ -f client-vpn-$client_name.deb ]; then
    echo "Пакет deb успешно создан: client-vpn-$client_name.deb"
else
    echo "Ошибка при создании пакета deb."
fi



