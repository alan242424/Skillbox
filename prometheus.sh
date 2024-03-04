#!/bin/bash


# Запрос данных у пользователя
echo "Введите адрес сервера VPN: "; read vpn_server

echo "Введите адрес сервера Центра сертификации: "; read ca_server

echo "Введите адрес сервера Backup: "; read backup_server

echo "Введите порт для node-exporter  с которого будут собираться данные по умолчанию  9100:"; read node_port
if [[ -z $node_port ]]; then
	node_port="9100"

echo "Введите порт для openvpn-exporter с которого будут собираться данные , по умолчанию 9176:"; read openexp_port
if [[ -z $openexp_port ]]; then
	openexp_port="9176"




touch /etc/prometheus/rules.yml
# Создание конфигурационного файла
cat << EOF > /etc/prometheus/prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'Node-exporter-server-vpn'
    static_configs:
      - targets: ['$vpn_server:$node_port']
 
  - job_name: 'Openvpn-exporter-server-vpn'
    static_configs: 
      - targets: ['$vpn_server:$openexp_port']
 
  - job_name: 'CA-server'
    static_configs:
      - targets: ['$ca_server:$node_port']

  - job_name: 'backup-server'
    static_configs:
      - targets: ['$backup_server:$node_port']

  - job_name: 'local_prometheus'
    static_configs:
      - targets: ['localhost:9100']

rule_files:
  - rules.yml
      
alerting:
  alertmanagers:
  - static_configs:
    - targets: ['localhost:9093']

EOF
# Создание правил
# Правило для проверки доступности сервера:
cat << EOF > /etc/prometheus/rules.yml
# Правило для проверки доступности сервера:
groups:
- name: "Node-Exporter"
  rules:
  - alert: InstanceDown
    expr: up == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      title: "Instance {{ $labels.instance }} is down"


# Правило для мониторинга использования CPU:
  - alert: HighCpuUsage
    expr: 100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 90
    for: 5m
    labels:
     severity: warning
    annotations:
      title: "High CPU usage on {{ $labels.instance }}"

# Правило для отслеживания использования памяти
  - alert: HighMemoryUsage
    expr: (node_memory_MemTotal_bytes - node_memory_MemFree_bytes) / node_memory_MemTotal_bytes * 100 > 90
    for: 5m
    labels:
     severity: warning
    annotations:
      title: "High memory usage on {{ $labels.instance }}"

  - alert: DiskSpaceLow
    expr: node_filesystem_free_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"} * 100 < 10
    for: 5m
    labels:
     severity: warning
  annotations:
    title: ""Available disk space on {{ $labels.instance }}is below 10%"
    description: "Disk space usage has exceeded 90%. It is necessary to free up space or increase the available disk space."


# Проверка статуса VPN клиентов
- name: "Openvpn_Exporter"
  rules:
  - alert: OpenVPNClientStatusDown
    expr: openvpn_client_status{status="down"} > 0
    for: 10m
    labels:
     severity: warning
    annotations:
     title: "OpenVPN client(s) are down"
     description: "One or more OpenVPN clients are in 'down' state."

# Мониторинг использования трафика на сервере
  - alert: OpenVPNTrafficHigh
    expr: rate(openvpn_bytes_received_total[5m]) + rate(openvpn_bytes_sent_total[5m]) > 1e6
    for: 10m
    labels:
     severity: warning
    annotations:
     title: "High OpenVPN traffic usage"
     description: "The total incoming and outgoing traffic on the OpenVPN server is above 1MB/s."

# Мониторинг количества активных подключений  
  - alert: OpenVPNConnectionsHigh
    expr: openvpn_connections_total > 100
    for: 5m
    labels:
     severity: warning
    annotations:
     title: "High number of OpenVPN connections"
     description: "The number of active OpenVPN connections is above the threshold."
                                                                                      
EOF

echo "Введите адрес электронной почты для получения уведомлений(по умолчанию:alantsogoev24@gmail):"; read to_email
if [[ -z $to_email ]]; then
        to_email="alantsogoev24@gmail.com"
fi
echo "Введите адрес электронной почты отправителя(по умолчанию:alantsogoev24@gmail.com):"; read from_email
if [[ -z $from_email ]]; then
	from_email="alantsogoev24@gmail.com"
fi	

echo "Введите SMTP-хост (по умолчанию: smtp.gmail.com):"; read host_smtp
if [[ -z $host_smtp ]]; then
	host_smtp="smtp.gmail.com"
fi	

echo "Введите SMTP-порт (по умолчанию: 587):"; read port_smtp
if [[ -z $port_smtp ]]; then
	port_smtp="587"
fi
echo "Введите имя пользователя (адрес электронной почты, по умолчанию:alantsogoev24@gmail):"; read username
if [[ -z $username ]]; then
	username="alantsogoev24@gmail.com"
fi	
echo "Введите пароль пользователя:"; read password 

# Создание конфигурационного файла Alertmanager
cat << EOF > /etc/prometheus/alertmanager.yml
global:
  resolve_timeout: 1m
route:
  receiver: 'alantsogoev24@gmail.com'
  group_wait: 30s
  group_interval: 1m
  repeat_interval: 5m

receivers:
- name: '$username'
  email_configs:
  - to: '$to_email'
    from: '$from_email'
    smarthost: '$host_smtp:$port_smtp'
    auth_username: '$username'
    auth_password: '$password'

EOF

# Запуск Prometheus
systemctl start prometheus
systemctl start prometheus-alertmanager

