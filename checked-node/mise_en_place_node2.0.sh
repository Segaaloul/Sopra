#!/bin/bash

# === CONFIGURATION ===
USERNAME="sopra"
NODE_EXPORTER_VERSION="1.8.2"
BASE_DIR="/home/${USERNAME}/monitoring"
NODE_EXPORTER_BIN="${BASE_DIR}/node_exporter"
LOG_FILE="${BASE_DIR}/node_exporter.log"
SCRIPT_DIR="${BASE_DIR}"
TEXTFILE_DIR="${BASE_DIR}/node_exporter_textfiles"

# === DÉTECTION DE L’ARCHITECTURE ===
ARCH_RAW=$(uname -m)
case "$ARCH_RAW" in
    x86_64) ARCH="amd64" ;;
    aarch64 | arm64) ARCH="arm64" ;;
    armv7l) ARCH="armv7" ;;
    *) echo "❌ Architecture non supportée : $ARCH_RAW" && exit 1 ;;
esac
echo "✅ Architecture détectée : $ARCH_RAW → $ARCH"

# === DÉTECTION DU GESTIONNAIRE DE PAQUETS ===
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
echo "📦 Vérification des outils requis..."
eval "$PKG_INSTALL"

# === INSTALLATION NODE EXPORTER ===
echo "📥 Téléchargement de Node Exporter ${NODE_EXPORTER_VERSION}..."
wget https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}.tar.gz -P /tmp

echo "📂 Installation dans ${BASE_DIR}..."
mkdir -p "${BASE_DIR}"
cd /tmp
tar xvf node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}.tar.gz
mv node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}/node_exporter "${NODE_EXPORTER_BIN}"
rm -rf node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}*

chown ${USERNAME}:${USERNAME} "${NODE_EXPORTER_BIN}"
chmod +x "${NODE_EXPORTER_BIN}"

# === SCRIPTS D'EXPORTATION ===
mkdir -p "${TEXTFILE_DIR}"
chown -R ${USERNAME}:${USERNAME} "${SCRIPT_DIR}"

echo "📜 Création des scripts custom..."

# export_connected_user.sh
cat << 'EOF' > ${SCRIPT_DIR}/export_connected_user.sh
#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: $0 <nom_utilisateur>"
    exit 1
fi

USERNAME="$1"
TEXTFILE_DIR="/home/${USERNAME}/monitoring/node_exporter_textfiles"
OUTPUT_FILE="${TEXTFILE_DIR}/connected_users.prom"

mkdir -p "$TEXTFILE_DIR"
chown ${USERNAME}:${USERNAME} "$TEXTFILE_DIR"

USER_COUNT=$(who | wc -l)

cat <<EOL > "$OUTPUT_FILE"
# HELP connected_users Number of users connected via SSH or TTY
# TYPE connected_users gauge
connected_users $USER_COUNT
EOL

chown ${USERNAME}:${USERNAME} "$OUTPUT_FILE"
EOF

# export_systemd_status.sh
cat << 'EOF' > ${SCRIPT_DIR}/export_systemd_status.sh
#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: $0 <nom_utilisateur>"
    exit 1
fi

USERNAME="$1"
TEXTFILE_DIR="/home/${USERNAME}/monitoring/node_exporter_textfiles"
OUTPUT_FILE="${TEXTFILE_DIR}/systemd_services.prom"

mkdir -p "$TEXTFILE_DIR"
chown ${USERNAME}:${USERNAME} "$TEXTFILE_DIR"

cat <<EOL > "$OUTPUT_FILE"
# HELP systemd_service_state State of systemd services (1=active, 0=inactive)
# TYPE systemd_service_state gauge
EOL

systemctl list-units --type=service --no-pager --no-legend | awk '{print $1}' | while read -r SERVICE_NAME; do
    ACTIVE_STATE=$(systemctl is-active "$SERVICE_NAME" 2>/dev/null)
    if [ "$ACTIVE_STATE" == "active" ]; then
        VALUE=1
    else
        VALUE=0
    fi
    CLEAN_NAME=$(echo "$SERVICE_NAME" | sed 's/[^a-zA-Z0-9_]/_/g')
    echo "systemd_service_state{service=\"$CLEAN_NAME\"} $VALUE" >> "$OUTPUT_FILE"
done

chown ${USERNAME}:${USERNAME} "$OUTPUT_FILE"
EOF

# export_other_services.sh
cat << 'EOF' > ${SCRIPT_DIR}/export_other_services.sh
#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: $0 <nom_utilisateur>"
    exit 1
fi

USERNAME="$1"
TEXTFILE_DIR="/home/${USERNAME}/monitoring/node_exporter_textfiles"
OUTPUT_FILE="${TEXTFILE_DIR}/other_services.prom"

mkdir -p "$TEXTFILE_DIR"
chown ${USERNAME}:${USERNAME} "$TEXTFILE_DIR"

# Liste des services à vérifier
SERVICES=("adm" "openhr" "query" "tomweb" "tombatch" "TOMWEBEST")

# En-têtes pour Prometheus
cat <<EOL > "$OUTPUT_FILE"
# HELP service_active Indique si le service est actif (1=actif, 0=inactif)
# TYPE service_active gauge
EOL

for SERVICE in "${SERVICES[@]}"; do
    STATUS=$(systemctl is-active "$SERVICE" 2>/dev/null)
    if [ "$STATUS" = "active" ]; then
        VALUE=1
    else
        VALUE=0
    fi
    # Remplace les caractères non conformes pour le nom métrique et convertit en minuscules
    CLEAN_NAME=$(echo "$SERVICE" | sed 's/[^a-zA-Z0-9_]/_/g' | tr '[:upper:]' '[:lower:]')
    echo "service_active{service=\"$CLEAN_NAME\"} $VALUE" >> "$OUTPUT_FILE"
done

chown ${USERNAME}:${USERNAME} "$OUTPUT_FILE"
EOF


chmod +x ${SCRIPT_DIR}/export_*.sh
chown ${USERNAME}:${USERNAME} ${SCRIPT_DIR}/export_*.sh

# === CRONTAB ===
echo "🕒 Ajout des tâches dans la crontab..."

(crontab -u "${USERNAME}" -l 2>/dev/null | grep -v -e "node_exporter" -e "export_connected_user" -e "export_systemd_status" ; \
echo "* * * * * ${NODE_EXPORTER_BIN} --collector.textfile.directory=${TEXTFILE_DIR} --collector.systemd > ${LOG_FILE} 2>&1" ; \
echo "* * * * * ${SCRIPT_DIR}/export_connected_user.sh ${USERNAME}" ; \
echo "* * * * * ${SCRIPT_DIR}/export_other_services.sh ${USERNAME}" ; \
echo "* * * * * ${SCRIPT_DIR}/export_systemd_status.sh ${USERNAME}" ) | crontab -u "${USERNAME}" -

# === FIN ===
echo "✅ Installation complète."
echo "🌐 Node Exporter : http://$(hostname -I | awk '{print $1}'):9100/metrics"
echo "📁 Textfile collector : ${TEXTFILE_DIR}"
echo "📄 Logs : ${LOG_FILE}"