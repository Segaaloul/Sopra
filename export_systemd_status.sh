#!/bin/bash
# Exporte l'état des services systemd pour node_exporter textfile_collector

# Vérification de l'argument utilisateur
if [ -z "$1" ]; then
    echo "Usage: $0 <nom_utilisateur>"
    exit 1
fi

USERNAME="$1"
TEXTFILE_DIR="/home/${USERNAME}/monitoring/node_exporter_textfiles"
OUTPUT_FILE="${TEXTFILE_DIR}/systemd_services.prom"

# Créer le dossier si manquant
mkdir -p "$TEXTFILE_DIR"
chown ${USERNAME}:${USERNAME} "$TEXTFILE_DIR"

# Écriture de l'en-tête Prometheus
cat <<EOF > "$OUTPUT_FILE"
# HELP systemd_service_state State of systemd services (1=active, 0=inactive)
# TYPE systemd_service_state gauge
EOF

# Parcourir les services systemd
systemctl list-units --type=service --no-pager --no-legend | awk '{print $1}' | while read -r SERVICE_NAME; do
    ACTIVE_STATE=$(systemctl is-active "$SERVICE_NAME" 2>/dev/null)
    if [ "$ACTIVE_STATE" == "active" ]; then
        VALUE=1
    else
        VALUE=0
    fi

    # Nettoyage éventuel du nom
    CLEAN_NAME=$(echo "$SERVICE_NAME" | sed 's/[^a-zA-Z0-9_]/_/g')
    echo "systemd_service_state{service=\"$CLEAN_NAME\"} $VALUE" >> "$OUTPUT_FILE"
done

chown ${USERNAME}:${USERNAME} "$OUTPUT_FILE"

#* * * * * /home/<user>/monitoring/export_systemd_status.sh <user>. a meyttre dans le crontab

