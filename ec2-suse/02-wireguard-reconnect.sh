#!/bin/bash
# =============================================================
# Script 2 : Reconnexion WireGuard après redémarrage d'instance
# Met à jour l'IP publique dans la config client
# =============================================================
#
# Usage :
#   - Automatique au boot (via le service systemd wg-update-ip)
#   - Manuel :
#       sudo wg-reconnect          → affiche config + QR code
#       sudo wg-reconnect --qr     → affiche uniquement le QR code (mobile)
#       sudo wg-reconnect --conf   → affiche uniquement la config (PC)
#       sudo wg-reconnect --auto   → mise à jour silencieuse (pour systemd)
#
# =============================================================

set -e

# --- Configuration ---
WG_PORT=51820
CLIENT_DIR="/root/wireguard-clients"
WG_DIR="/etc/wireguard"
DNS="1.1.1.1, 1.0.0.1"

MODE="${1:-}"

# --- Récupération des clés existantes ---
SERVER_PUBLIC_KEY=$(cat ${WG_DIR}/server_public.key)
CLIENT_PRIVATE_KEY=$(cat ${CLIENT_DIR}/client_private.key)
CLIENT_PSK=$(cat ${CLIENT_DIR}/client_psk.key)

# --- Détection de la nouvelle IP publique ---
echo "Détection de l'IP publique..."
NEW_IP=""
for i in 1 2 3 4 5; do
    NEW_IP=$(curl -s --max-time 5 https://api.ipify.org) && break
    echo "Tentative ${i}/5 échouée, nouvel essai dans 3s..."
    sleep 3
done

if [ -z "$NEW_IP" ]; then
    echo "ERREUR : Impossible de détecter l'IP publique."
    exit 1
fi

# --- Vérification si l'IP a changé ---
OLD_IP=$(grep -oP 'Endpoint = \K[^:]+' ${CLIENT_DIR}/client.conf 2>/dev/null || echo "")

if [ "$OLD_IP" = "$NEW_IP" ]; then
    echo "L'IP n'a pas changé (${NEW_IP}). Rien à faire."
    [ "$MODE" = "--auto" ] && exit 0
else
    echo "Nouvelle IP détectée : ${OLD_IP:-aucune} → ${NEW_IP}"
fi

# --- Mise à jour de la config client ---
cat > ${CLIENT_DIR}/client.conf << EOF
[Interface]
PrivateKey = ${CLIENT_PRIVATE_KEY}
Address = 10.66.66.2/32
DNS = ${DNS}

[Peer]
PublicKey = ${SERVER_PUBLIC_KEY}
PresharedKey = ${CLIENT_PSK}
Endpoint = ${NEW_IP}:${WG_PORT}
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

echo "Config client mise à jour avec l'IP ${NEW_IP}"

# --- Mode silencieux pour systemd ---
if [ "$MODE" = "--auto" ]; then
    echo "Mise à jour automatique terminée."
    exit 0
fi

# --- Affichage selon le mode ---
echo ""
echo "=========================================="
echo "  WireGuard — Nouvelle configuration"
echo "  IP : ${NEW_IP}"
echo "=========================================="

if [ "$MODE" != "--conf" ]; then
    echo ""
    echo "--- MOBILE : Scanne ce QR Code ---"
    echo ""
    qrencode -t ansiutf8 < ${CLIENT_DIR}/client.conf
fi

if [ "$MODE" != "--qr" ]; then
    echo ""
    echo "--- PC : Copie cette config ---"
    echo ""
    cat ${CLIENT_DIR}/client.conf
    echo ""
    echo "--- Ou télécharge via SCP : ---"
    echo "  scp -i ta-cle.pem ec2-user@${NEW_IP}:${CLIENT_DIR}/client.conf ."
fi

echo ""
echo "=========================================="
