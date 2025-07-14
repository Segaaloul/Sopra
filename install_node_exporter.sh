#!/bin/bash
#Voici un script bash modifié pour installer Node Exporter sur Ubuntu 22.04 (ARM) sans créer d'utilisateur et 
#sans vérifier les privilèges root, en utilisant l'utilisateur existant selim
# Variables
NODE_EXPORTER_VERSION="1.8.2"
ARCH="arm64"
INSTALL_DIR="/usr/local/bin"
SERVICE_DIR="/etc/systemd/system"

# Mettre à jour le système
echo "Mise à jour du système..."
apt update && apt upgrade -y

# Télécharger Node Exporter
echo "Téléchargement de Node Exporter version ${NODE_EXPORTER_VERSION}..."
wget https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}.tar.gz

# Extraire et installer
echo "Installation de Node Exporter..."
tar xvf node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}.tar.gz
mv node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}/node_exporter ${INSTALL_DIR}/node_exporter
rm -rf node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}*
chown selim:selim ${INSTALL_DIR}/node_exporter
chmod +x ${INSTALL_DIR}/node_exporter

# Créer le service systemd
echo "Création du service systemd..."
cat > ${SERVICE_DIR}/node_exporter.service << EOF
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=selim
Group=selim
Type=simple
ExecStart=${INSTALL_DIR}/node_exporter

[Install]
WantedBy=multi-user.target
EOF

# Activer et démarrer le service
echo "Activation et démarrage du service..."
systemctl daemon-reload
systemctl enable node_exporter
systemctl start node_exporter

# Vérifier le statut
echo "Vérification du statut du service..."
systemctl status node_exporter --no-pager

# Afficher l'info de connexion
echo "Node Exporter est installé !"
echo "Accessible sur http://$(hostname -I | awk '{print $1}'):9100/metrics"