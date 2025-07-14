#!/bin/bash
# Installer Node Exporter avec crontab -e, détection d’architecture et support textfile_collector
#----------
# Note , ce script permet , d installer node exporter , respectant l architecture du serveur , de configurer le crontab -e et de créer un dossier textfile_collector pour les metriques,
#  en prenant en paramaitre le nom de l'utilisateur.
#
#option: si on veut installer WGET et TAR il faute decommenter les lignes ci-dessous
#----------


# Vérification argument utilisateur
if [ -z "$1" ]; then
    echo "Usage : $0 <nom_utilisateur>"
    exit 1
fi

USERNAME="$1"
INSTALL_DIR="/home/${USERNAME}/monitoring"
NODE_EXPORTER_BIN="${INSTALL_DIR}/node_exporter"
LOG_FILE="/tmp/node_exporter.log"
TEXTFILE_DIR="${INSTALL_DIR}/node_exporter_textfiles"
NODE_EXPORTER_VERSION="1.8.2"

# Détection architecture
ARCH_RAW=$(uname -m)
case "$ARCH_RAW" in
    x86_64) ARCH="amd64" ;;
    aarch64 | arm64) ARCH="arm64" ;;
    armv7l) ARCH="armv7" ;;
    *) echo "❌ Architecture non supportée : $ARCH_RAW" && exit 1 ;;
esac
echo "✅ Architecture détectée : $ARCH_RAW → $ARCH"

# Détection du gestionnaire de paquets
if command -v apt >/dev/null 2>&1; then
    echo "🔧 Distribution basée sur Debian/Ubuntu"
    PKG_INSTALL="apt update && apt install -y wget tar"
elif command -v yum >/dev/null 2>&1; then
    echo "🔧 Distribution basée sur RHEL/CentOS"
    PKG_INSTALL="yum install -y wget tar"
elif command -v dnf >/dev/null 2>&1; then
    echo "🔧 Distribution basée sur Fedora/RHEL 8+"
    PKG_INSTALL="dnf install -y wget tar"
else
    echo "❌ Gestionnaire de paquets non supporté"
    exit 1
fi

# Installer wget et tar si manquants
#echo "📦 Vérification des outils requis..."
#eval "$PKG_INSTALL"

# Télécharger Node Exporter
echo "⬇️  Téléchargement de Node Exporter v${NODE_EXPORTER_VERSION} pour ${ARCH}..."
wget -q https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}.tar.gz

# Extraction
echo "📦 Installation de Node Exporter..."
tar -xzf node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}.tar.gz
mv node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}/node_exporter ${NODE_EXPORTER_BIN}
rm -rf node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}*
chown ${USERNAME}:${USERNAME} ${NODE_EXPORTER_BIN}
chmod +x ${NODE_EXPORTER_BIN}

# Dossier textfile_collector
echo "📁 Création du dossier textfile_collector : ${TEXTFILE_DIR}"
mkdir -p ${TEXTFILE_DIR}
chown ${USERNAME}:${USERNAME} ${TEXTFILE_DIR}

# Crontab
echo "🕓 Ajout dans la crontab de ${USERNAME}..."
CRON_LINE="* * * * * ${NODE_EXPORTER_BIN} --collector.textfile.directory=${TEXTFILE_DIR} > ${LOG_FILE} 2>&1 "
( crontab -u "${USERNAME}" -l 2>/dev/null | grep -v "node_exporter" ; echo "${CRON_LINE}" ) | crontab -u "${USERNAME}" -

# Infos finales
echo "✅ Node Exporter installé avec textfile_collector"
echo "🌍 Accessible : http://$(hostname -I | awk '{print $1}'):9100/metrics"
echo "📄 Logs : ${LOG_FILE}"
