#!/bin/bash
# Exporte le nombre d'utilisateurs connectés pour node_exporter textfile_collector

# Vérification de l'argument utilisateur
if [ -z "$1" ]; then
    echo "Usage: $0 <nom_utilisateur>"
    exit 1
fi

USERNAME="$1"
TEXTFILE_DIR="/home/${USERNAME}/monitoring/node_exporter_textfiles"
OUTPUT_FILE="${TEXTFILE_DIR}/connected_users.prom"

# Créer le dossier si manquant
mkdir -p "$TEXTFILE_DIR"
chown ${USERNAME}:${USERNAME} "$TEXTFILE_DIR"

# Nombre d'utilisateurs connectés via SSH ou TTY
USER_COUNT=$(who | wc -l)

# Écriture dans le fichier au format Prometheus
cat <<EOF > "$OUTPUT_FILE"
# HELP connected_users Number of users connected via SSH or TTY
# TYPE connected_users gauge
connected_users $USER_COUNT
EOF

chown ${USERNAME}:${USERNAME} "$OUTPUT_FILE"

#* * * * * /home/<user>/monitoring/export_connected_user.sh <user> , a mettre dans le crontab
