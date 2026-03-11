#!/bin/bash
# =============================================================
# Launch Script Lightsail — Installation automatique WireGuard
# Ubuntu 24.04 LTS
# =============================================================

set -e

# --- Configuration ---
WG_PORT=51820
WG_INTERFACE="wg0"
SERVER_PRIVATE_KEY=""
SERVER_PUBLIC_KEY=""
CLIENT_PRIVATE_KEY=""
CLIENT_PUBLIC_KEY=""
CLIENT_PSK=""
WG_NETWORK="10.66.66.0/24"
SERVER_WG_IP="10.66.66.1/24"
CLIENT_WG_IP="10.66.66.2/32"
DNS="1.1.1.1, 1.0.0.1"

# --- Mise à jour du système ---
echo "[1/6] Mise à jour du système..."
apt-get update -y
apt-get upgrade -y

# --- Installation de WireGuard ---
echo "[2/6] Installation de WireGuard..."
apt-get install -y wireguard qrencode

# --- Génération des clés ---
echo "[3/6] Génération des clés..."
SERVER_PRIVATE_KEY=$(wg genkey)
SERVER_PUBLIC_KEY=$(echo "$SERVER_PRIVATE_KEY" | wg pubkey)
CLIENT_PRIVATE_KEY=$(wg genkey)
CLIENT_PUBLIC_KEY=$(echo "$CLIENT_PRIVATE_KEY" | wg pubkey)
CLIENT_PSK=$(wg genpsk)

# --- Détection de l'IP publique et de l'interface réseau ---
SERVER_PUBLIC_IP=$(curl -s https://api.ipify.org)
SERVER_NIC=$(ip -4 route ls | grep default | awk '{print $5}' | head -1)

# --- Configuration serveur ---
echo "[4/6] Configuration du serveur WireGuard..."
cat > /etc/wireguard/${WG_INTERFACE}.conf << EOF
[Interface]
PrivateKey = ${SERVER_PRIVATE_KEY}
Address = ${SERVER_WG_IP}
ListenPort = ${WG_PORT}
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o ${SERVER_NIC} -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o ${SERVER_NIC} -j MASQUERADE

[Peer]
PublicKey = ${CLIENT_PUBLIC_KEY}
PresharedKey = ${CLIENT_PSK}
AllowedIPs = ${CLIENT_WG_IP}
EOF

chmod 600 /etc/wireguard/${WG_INTERFACE}.conf

# --- Activation de l'IP forwarding ---
echo "[5/6] Activation de l'IP forwarding..."
echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/99-wireguard.conf
sysctl -p /etc/sysctl.d/99-wireguard.conf

# --- Démarrage de WireGuard ---
echo "[6/6] Démarrage de WireGuard..."
systemctl enable wg-quick@${WG_INTERFACE}
systemctl start wg-quick@${WG_INTERFACE}

# --- Génération du fichier de config client ---
CLIENT_CONF="/root/client-wireguard.conf"
cat > ${CLIENT_CONF} << EOF
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

# --- QR Code pour mobile ---
echo ""
echo "=========================================="
echo "  WireGuard installé avec succès !"
echo "=========================================="
echo ""
echo "Config client sauvegardée dans : ${CLIENT_CONF}"
echo ""
echo "Pour récupérer le fichier :"
echo "  scp user@${SERVER_PUBLIC_IP}:${CLIENT_CONF} ."
echo ""
echo "QR Code pour l'appli mobile :"
echo ""
qrencode -t ansiutf8 < ${CLIENT_CONF}
echo ""
echo "=========================================="
echo "N'oublie pas d'ouvrir le port UDP ${WG_PORT}"
echo "dans le pare-feu Lightsail !"
echo "=========================================="
