#!/bin/bash
# Voici un script bash modifié pour installer Prometheus et cree le service
# sur Ubuntu 22.04 (ARM) sans créer d'utilisateur et sans verifier les privilèges root
# Configuration
USER="selim"
PROM_VERSION="2.52.0"
ARCH="arm64"
INSTALL_DIR="/home/$USER"
PROM_PATH="${INSTALL_DIR}/prometheus-${PROM_VERSION}.linux-${ARCH}"

# Mettre à jour le système
echo "Mise à jour du système..."
sudo apt update && sudo apt upgrade -y

# Télécharger Prometheus
echo "Téléchargement de Prometheus version ${PROM_VERSION}..."
wget https://github.com/prometheus/prometheus/releases/download/v${PROM_VERSION}/prometheus-${PROM_VERSION}.linux-${ARCH}.tar.gz -P /tmp

# Extraire et installer Prometheus
echo "Installation de Prometheus..."
tar xvf /tmp/prometheus-${PROM_VERSION}.linux-${ARCH}.tar.gz -C ${INSTALL_DIR}
chown -R ${USER}:${USER} ${PROM_PATH}
rm /tmp/prometheus-${PROM_VERSION}.linux-${ARCH}.tar.gz

# Créer le fichier de configuration prometheus.yml si absent
if [ ! -f "${PROM_PATH}/prometheus.yml" ]; then
    echo "Création du fichier de configuration prometheus.yml..."
    cat > ${PROM_PATH}/prometheus.yml << EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
EOF
    chown ${USER}:${USER} ${PROM_PATH}/prometheus.yml
fi

# Créer le service Prometheus
echo "Création du service Prometheus..."
sudo tee /etc/systemd/system/prometheus.service > /dev/null <<EOF
[Unit]
Description=Prometheus Monitoring
Wants=network-online.target
After=network-online.target

[Service]
User=${USER}
ExecStart=${PROM_PATH}/prometheus \\
  --config.file=${PROM_PATH}/prometheus.yml \\
  --storage.tsdb.path=${PROM_PATH}/data
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Recharger systemd et activer le service
echo "Rechargement de systemd et activation du service..."
sudo systemctl daemon-reload
sudo systemctl enable prometheus

# Démarrer le service
echo "Démarrage du service..."
sudo systemctl start prometheus

# Vérifier le statut du service
echo "Vérification du statut du service..."
systemctl status prometheus --no-pager

# Afficher les informations de connexion
echo "✅ Installation terminée !"
echo "Prometheus est accessible sur http://$(hostname -I | awk '{print $1}'):9090"
echo "Vérifiez le service avec : systemctl status prometheus"


#Pour l execution : sudo ./install_prometheus.sh