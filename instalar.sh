#!/bin/bash

set -e

### CONFIGURAÇÕES INICIAIS ###
ZABBIX_HOSTNAME="zabbix-server"
ZABBIX_DOMINIO="ti.agencialoi.com"
ZABBIX_ALIAS="Dash"
ZABBIX_DB_USER="zabbix"
ZABBIX_DB_PASS="L01@2025"
ZABBIX_DB_NAME="zabbix"
TZ="America/Sao_Paulo"

### ATUALIZA E INSTALA DEPENDÊNCIAS ###
echo "🔧 Atualizando sistema e instalando pacotes..."
apt update && apt upgrade -y
apt install -y apache2 mysql-server php php-mysql php-gd php-xml php-bcmath php-mbstring php-ldap php-json php-curl php-zip php-intl libapache2-mod-php wget gnupg2 ufw unzip certbot python3-certbot-apache lsb-release

### INICIA MYSQL ###
echo "🚀 Iniciando MySQL..."
systemctl enable mysql
systemctl restart mysql

### CONFIGURA TIMEZONE PHP ###
echo "🕓 Configurando timezone do PHP..."
PHP_INI=$(find /etc/php/ -name php.ini | grep apache2 | head -n1)
echo "date.timezone = $TZ" >> "$PHP_INI"

### SEGURANÇA DO MYSQL ###
echo "🔐 Executando segurança do MySQL..."
mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$ZABBIX_DB_PASS'; FLUSH PRIVILEGES;"

### INSTALA ZABBIX 7.2 ###
echo "📦 Instalando Zabbix 7.2..."
wget https://repo.zabbix.com/zabbix/7.2/ubuntu/pool/main/z/zabbix-release/zabbix-release_7.2-1+ubuntu22.04_all.deb
dpkg -i zabbix-release_7.2-1+ubuntu22.04_all.deb
apt update
apt install -y zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf zabbix-sql-scripts zabbix-agent

### CRIA BASE DE DADOS ###
echo "📂 Criando banco de dados do Zabbix..."
mysql -uroot -p"$ZABBIX_DB_PASS" -e "CREATE DATABASE $ZABBIX_DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;"
mysql -uroot -p"$ZABBIX_DB_PASS" -e "CREATE USER '$ZABBIX_DB_USER'@'localhost' IDENTIFIED BY '$ZABBIX_DB_PASS';"
mysql -uroot -p"$ZABBIX_DB_PASS" -e "GRANT ALL PRIVILEGES ON $ZABBIX_DB_NAME.* TO '$ZABBIX_DB_USER'@'localhost';"
mysql -uroot -p"$ZABBIX_DB_PASS" -e "FLUSH PRIVILEGES;"
zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql -u$ZABBIX_DB_USER -p$ZABBIX_DB_PASS $ZABBIX_DB_NAME

### CONFIGURA SERVER ###
echo "⚙️ Configurando Zabbix Server..."
sed -i "s/^# DBPassword=/DBPassword=$ZABBIX_DB_PASS/" /etc/zabbix/zabbix_server.conf

### ALTERA O ALIAS DO PAINEL ###
echo "🎨 Alterando alias padrão para /$ZABBIX_ALIAS..."
sed -i "s|Alias /zabbix /usr/share/zabbix|Alias /$ZABBIX_ALIAS /usr/share/zabbix|" /etc/apache2/conf-enabled/zabbix.conf

### CONFIGURA SSL ###
echo "🔒 Gerando certificado SSL com Let's Encrypt..."
certbot --apache --non-interactive --agree-tos -m admin@$ZABBIX_DOMINIO -d $ZABBIX_DOMINIO || echo "⚠️ Certbot falhou (domínio pode não estar apontado ainda)."

### ATIVA SERVIÇOS ###
echo "✅ Ativando serviços..."
systemctl enable zabbix-server zabbix-agent apache2 mysql
systemctl restart zabbix-server zabbix-agent apache2 mysql

### FIREWALL ###
echo "🛡️ Configurando firewall..."
ufw allow 22
ufw allow 80
ufw allow 443
ufw allow 10051/tcp
ufw --force enable

### FINALIZAÇÃO ###
echo "✅ Instalação concluída com sucesso!"
echo "🌐 Acesse: https://$ZABBIX_DOMINIO/$ZABBIX_ALIAS"
echo "🔐 Login: Admin / zabbix"
