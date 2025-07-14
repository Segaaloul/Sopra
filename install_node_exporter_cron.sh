#!/bin/bash
# Installer Node Exporter (ARM, Ubuntu 22.04) et ajouter à crontab -e sans systemd



USERNAME="selim"
NODE_EXPORTER_VERSION="1.8.2"
ARCH="arm64"
INSTALL_DIR="/home/selim"
NODE_EXPORTER_BIN="${INSTALL_DIR}/node_exporter"
LOG_FILE="/tmp/node_exporter.log"

# Mise à jour système
echo "Mise à jour du système..."
apt update && apt upgrade -y

# Téléchargement Node Exporter
echo "Téléchargement de Node Exporter ${NODE_EXPORTER_VERSION}..."
wget https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}.tar.gz

# Extraction et installation
echo "Installation..."
tar xvf node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}.tar.gz
mv node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}/node_exporter ${NODE_EXPORTER_BIN}
rm -rf node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}*
chown ${USERNAME}:${USERNAME} ${NODE_EXPORTER_BIN}
chmod +x ${NODE_EXPORTER_BIN}

# Ajout dans la crontab du bon utilisateur
echo "Ajout à la crontab de l'utilisateur ${USERNAME}..."
CRON_LINE="* * * * * ${NODE_EXPORTER_BIN} > ${LOG_FILE} 2>&1 &"
( crontab -u "${USERNAME}" -l 2>/dev/null | grep -v "node_exporter" ; echo "${CRON_LINE}" ) | crontab -u "${USERNAME}" -

# Info
echo "✅ Node Exporter installé et configuré dans la crontab de ${USERNAME}."
echo "🌐 Accessible sur : http://$(hostname -I | awk '{print $1}'):9100/metrics"
echo "📄 Logs : ${LOG_FILE}"
