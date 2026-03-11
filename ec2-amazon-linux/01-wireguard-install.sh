#!/bin/bash
# =============================================================
# Script 1 : Installation initiale de WireGuard
# Amazon Linux 2023 (EC2) — À lancer une seule fois (User Data ou SSH)
# =============================================================

set -e

# --- Configuration ---
WG_PORT=51820
WG_INTERFACE="wg0"
WG_DIR="/etc/wireguard"
CLIENT_DIR="/root/wireguard-clients"
DNS="1.1.1.1, 1.0.0.1"

# --- Mise à jour du système ---
echo "[1/7] Mise à jour du système..."
dnf update -y

# --- Installation des paquets ---
echo "[2/7] Installation de WireGuard..."
dnf install -y wireguard-tools qrencode iptables

# --- Chargement du module kernel ---
modprobe wireguard
echo "wireguard" > /etc/modules-load.d/wireguard.conf

# --- Génération des clés serveur ---
echo "[3/7] Génération des clés serveur..."
mkdir -p ${WG_DIR}
wg genkey | tee ${WG_DIR}/server_private.key | wg pubkey > ${WG_DIR}/server_public.key
chmod 600 ${WG_DIR}/server_private.key

SERVER_PRIVATE_KEY=$(cat ${WG_DIR}/server_private.key)
SERVER_PUBLIC_KEY=$(cat ${WG_DIR}/server_public.key)

# --- Génération des clés client ---
echo "[4/7] Génération des clés client..."
mkdir -p ${CLIENT_DIR}
wg genkey | tee ${CLIENT_DIR}/client_private.key | wg pubkey > ${CLIENT_DIR}/client_public.key
wg genpsk > ${CLIENT_DIR}/client_psk.key
chmod 600 ${CLIENT_DIR}/*.key

CLIENT_PRIVATE_KEY=$(cat ${CLIENT_DIR}/client_private.key)
CLIENT_PUBLIC_KEY=$(cat ${CLIENT_DIR}/client_public.key)
CLIENT_PSK=$(cat ${CLIENT_DIR}/client_psk.key)

# --- Détection IP publique et interface réseau ---
echo "[5/7] Détection de l'IP publique..."
SERVER_PUBLIC_IP=$(curl -s https://api.ipify.org)
SERVER_NIC=$(ip -4 route ls | grep default | awk '{print $5}' | head -1)

# Sauvegarde de l'interface réseau pour le script de reconnexion
echo "${SERVER_NIC}" > ${WG_DIR}/server_nic

# --- Configuration serveur WireGuard ---
echo "[6/7] Configuration du serveur..."
cat > ${WG_DIR}/${WG_INTERFACE}.conf << EOF
[Interface]
PrivateKey = ${SERVER_PRIVATE_KEY}
Address = 10.66.66.1/24
ListenPort = ${WG_PORT}
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o ${SERVER_NIC} -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o ${SERVER_NIC} -j MASQUERADE

[Peer]
PublicKey = ${CLIENT_PUBLIC_KEY}
PresharedKey = ${CLIENT_PSK}
AllowedIPs = 10.66.66.2/32
EOF

chmod 600 ${WG_DIR}/${WG_INTERFACE}.conf

# --- Activation de l'IP forwarding ---
echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/99-wireguard.conf
sysctl -p /etc/sysctl.d/99-wireguard.conf

# --- Démarrage et activation au boot ---
echo "[7/7] Démarrage de WireGuard..."
systemctl enable wg-quick@${WG_INTERFACE}
systemctl start wg-quick@${WG_INTERFACE}

# --- Installation du script de reconnexion ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cp "${SCRIPT_DIR}/02-wireguard-reconnect.sh" /usr/local/bin/wg-reconnect
chmod +x /usr/local/bin/wg-reconnect

# --- Création du service systemd pour mise à jour auto de l'IP au boot ---
cat > /etc/systemd/system/wg-update-ip.service << 'UNIT'
[Unit]
Description=Met à jour la config client WireGuard avec la nouvelle IP publique
After=network-online.target wg-quick@wg0.service
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/wg-reconnect --auto

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable wg-update-ip.service

# --- Génération de la config client ---
cat > ${CLIENT_DIR}/client.conf << EOF
[Interface]
PrivateKey = ${CLIENT_PRIVATE_KEY}
Address = 10.66.66.2/32
DNS = ${DNS}

[Peer]
PublicKey = ${SERVER_PUBLIC_KEY}
PresharedKey = ${CLIENT_PSK}
Endpoint = ${SERVER_PUBLIC_IP}:${WG_PORT}
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

# --- Affichage final ---
echo ""
echo "=========================================="
echo "  WireGuard installé avec succès !"
echo "=========================================="
echo ""
echo "IP publique du serveur : ${SERVER_PUBLIC_IP}"
echo ""
echo "--- MOBILE : Scanne ce QR Code ---"
echo ""
qrencode -t ansiutf8 < ${CLIENT_DIR}/client.conf
echo ""
echo "--- PC : Copie cette config ---"
echo ""
cat ${CLIENT_DIR}/client.conf
echo ""
echo "--- Ou télécharge via SCP : ---"
echo "  scp -i ta-cle.pem ec2-user@${SERVER_PUBLIC_IP}:${CLIENT_DIR}/client.conf ."
echo ""
echo "=========================================="
echo "  N'oublie pas d'ouvrir UDP ${WG_PORT}"
echo "  dans le Security Group EC2 !"
echo "=========================================="
