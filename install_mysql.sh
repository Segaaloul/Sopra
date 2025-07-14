#!/bin/bash
# Script pour installer MySQL sur Ubuntu 22.04 (ARM)

# Mettre à jour les paquets
apt update && apt upgrade -y

# Installer MySQL Server
apt install mysql-server -y

# Activer le service MySQL pour démarrer au boot
systemctl enable mysql

# Démarrer le service MySQL
systemctl start mysql

# Sécuriser l'installation de MySQL
mysql_secure_installation <<EOF

y
0
y
y
y
y
EOF

# Vérifier l'état du service
systemctl status mysql --no-pager

# Afficher un message de confirmation
echo "MySQL a été installé et sécurisé. Connectez-vous avec 'sudo mysql -u root -p'."