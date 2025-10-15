
#!/bin/bash
set -e

# ==========================================
# CONFIGURAÇÕES PRINCIPAIS
# ==========================================
APP_DIR="/opt/dns-manager"
GITHUB_REPO="https://github.com/henriquelucas/gerencia-dns.git"
DB_NAME="dns_manager"
DB_USER="dnsuser"
DB_PASS="dnspass"
WEB_PORT="8484"
DNS_HOSTS_DIR="${APP_DIR}/hosts"
DNS_HOSTS_FILE="${DNS_HOSTS_DIR}/blocked_hosts"
APACHE_CONF="/etc/apache2/sites-available/dns-manager.conf"

# ==========================================
# ATUALIZAÇÃO DO SISTEMA E INSTALAÇÃO DE PACOTES
# ==========================================
echo "🔄 Atualizando pacotes..."
apt update -y && apt upgrade -y

echo "📦 Instalando dependências..."
apt install -y apache2 php php-mysql mariadb-server git dnsmasq unzip sudo

# ==========================================
# COPIA OU ATUALIZA ARQUIVOS DO GITHUB
# ==========================================
echo "⬇️ Copiando/atualizando arquivos do GitHub..."

mkdir -p ${APP_DIR}

if [ -d "${APP_DIR}/.git" ]; then
    echo "📁 Repositório existente encontrado, atualizando arquivos..."
    cd ${APP_DIR}
    git reset --hard
    git pull
else
    TMP_DIR=$(mktemp -d)
    git clone ${GITHUB_REPO} ${TMP_DIR}
    # Copia todos os arquivos para a raiz de /opt/dns-manager
    cp -r ${TMP_DIR}/* ${APP_DIR}/
    rm -rf ${TMP_DIR}
fi

echo "✅ Arquivos do repositório copiados para ${APP_DIR}"

# ==========================================
# CRIA PASTA HOSTS SE NÃO EXISTIR
# ==========================================
mkdir -p ${DNS_HOSTS_DIR}
chown -R www-data:www-data ${APP_DIR} ${DNS_HOSTS_DIR}
chmod -R 775 ${DNS_HOSTS_DIR}

# ==========================================
# CONFIGURA MARIADB
# ==========================================
echo "🗄️ Configurando banco MariaDB..."
mysql -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';"
mysql -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# ==========================================
# CRIA AS TABELAS
# ==========================================
echo "🗃️ Criando tabelas..."
mysql -u${DB_USER} -p${DB_PASS} ${DB_NAME} <<SQL
CREATE TABLE IF NOT EXISTS usuarios (
  id INT AUTO_INCREMENT PRIMARY KEY,
  email VARCHAR(150) NOT NULL,
  senha CHAR(32) NOT NULL
);

CREATE TABLE IF NOT EXISTS lista (
  id INT AUTO_INCREMENT PRIMARY KEY,
  url VARCHAR(255) NOT NULL,
  tipo ENUM('bloqueado','permitido') NOT NULL DEFAULT 'bloqueado'
);
SQL

# ==========================================
# CRIA USUÁRIO ADMIN INICIAL
# ==========================================
echo "👤 Criando usuário admin inicial..."
mysql -u${DB_USER} -p${DB_PASS} ${DB_NAME} <<SQL
INSERT INTO usuarios (email, senha)
SELECT 'admin@admin.com', MD5('admin')
WHERE NOT EXISTS (SELECT 1 FROM usuarios WHERE email='admin@admin.com');
SQL

# ==========================================
# GERA O ARQUIVO PDO.PHP
# ==========================================
echo "⚙️ Criando pdo.php..."
cat > ${APP_DIR}/pdo.php <<PHP
<?php
\$dsn = 'mysql:host=localhost;dbname=${DB_NAME};charset=utf8mb4';
\$username = '${DB_USER}';
\$password = '${DB_PASS}';
try {
    \$pdo = new PDO(\$dsn, \$username, \$password);
    \$pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
} catch (PDOException \$e) {
    die('Erro ao conectar: ' . \$e->getMessage());
}
?>
PHP
chown www-data:www-data ${APP_DIR}/pdo.php

# ==========================================
# CONFIGURA APACHE NA PORTA 8484
# ==========================================
echo "⚡ Configurando Apache na porta ${WEB_PORT}..."
if ! grep -q "Listen ${WEB_PORT}" /etc/apache2/ports.conf; then
    echo "Listen ${WEB_PORT}" >> /etc/apache2/ports.conf
fi

cat > ${APACHE_CONF} <<CONF
<VirtualHost *:${WEB_PORT}>
    DocumentRoot ${APP_DIR}
    <Directory ${APP_DIR}>
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog \${APACHE_LOG_DIR}/dns-manager-error.log
    CustomLog \${APACHE_LOG_DIR}/dns-manager-access.log combined
</VirtualHost>
CONF

a2ensite dns-manager.conf
systemctl restart apache2

# ==========================================
# CONFIGURA DNSMASQ
# ==========================================
echo "🧩 Configurando dnsmasq..."
systemctl stop systemd-resolved || true
systemctl disable systemd-resolved || true
rm -f /etc/resolv.conf
echo "nameserver 1.1.1.1" > /etc/resolv.conf

if [ ! -f /etc/dnsmasq.conf.bak ]; then
    cp /etc/dnsmasq.conf /etc/dnsmasq.conf.bak
fi

cat > /etc/dnsmasq.conf <<CONF
port=53
domain-needed
bogus-priv
no-resolv
addn-hosts=${DNS_HOSTS_FILE}
log-queries
log-facility=/var/log/dnsmasq.log
CONF

# Cria arquivo base de hosts se não existir
if [ ! -f ${DNS_HOSTS_FILE} ]; then
    echo "127.0.0.1 localhost" > ${DNS_HOSTS_FILE}
fi
chown www-data:www-data ${DNS_HOSTS_FILE}
chmod 664 ${DNS_HOSTS_FILE}

systemctl enable dnsmasq
systemctl restart dnsmasq

# ==========================================
# PERMITIR PHP EXECUTAR RELOAD DO DNSMASQ
# ==========================================
echo "💡 Permitindo PHP recarregar dnsmasq..."
echo "www-data ALL=(ALL) NOPASSWD: /bin/systemctl reload dnsmasq" > /etc/sudoers.d/dnsmanager
chmod 440 /etc/sudoers.d/dnsmanager

# ==========================================
# FINALIZA
# ==========================================
echo "======================================"
echo "✅ Instalação concluída!"
echo "🌐 Acesse: http://$(hostname -I | awk '{print $1}'):${WEB_PORT}"
echo "📁 App: ${APP_DIR}"
echo "🗄️ Banco: ${DB_NAME} / Usuário: ${DB_USER}"
echo "👤 Admin: admin@admin.com / Senha: admin"
echo "🧱 DNS hosts: ${DNS_HOSTS_FILE}"
echo "======================================"
