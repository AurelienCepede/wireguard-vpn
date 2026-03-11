# WireGuard VPN — Scripts d'installation automatique

Scripts Bash pour déployer un serveur VPN WireGuard sur AWS (EC2 ou Lightsail) en quelques minutes.

## Contenu du repo

```
.
├── ec2-suse/
│   ├── 01-wireguard-install.sh    # Installation initiale (SUSE/EC2)
│   └── 02-wireguard-reconnect.sh  # Mise à jour auto de l'IP après redémarrage
├── lightsail-ubuntu/
│   └── lightsail-wireguard-launch-script.sh  # Launch Script Lightsail (Ubuntu 24.04)
└── README.md
```

## Prérequis

- Un compte AWS avec accès à EC2 ou Lightsail
- Une paire de clés SSH (ED25519 recommandé)
- L'application WireGuard installée sur ton appareil client ([iOS](https://apps.apple.com/app/wireguard/id1441195209) / [Android](https://play.google.com/store/apps/details?id=com.wireguard.android) / [Windows/Mac/Linux](https://www.wireguard.com/install/))

## Option 1 — EC2 avec SUSE Linux

Setup optimisé pour une instance EC2 à la demande (t2.nano ou t3.micro free tier).

### Création de l'instance

1. Dans la console AWS, sélectionne ta **région** en haut à droite
2. Lance une instance EC2 :
   - **AMI** : SUSE Linux Enterprise Server
   - **Type** : `t3.micro` (free tier) ou `t2.nano` (~0.0058$/h)
   - **Stockage** : gp3, 1 Go minimum
   - **Key Pair** : ED25519
3. Configure le **Security Group** — ajoute une règle Inbound :
   - Type : `Custom UDP`
   - Port : `51820`
   - Source : `0.0.0.0/0`

### Installation

Connecte-toi en SSH et lance les scripts :

```bash
ssh -i ta-cle.pem ec2-user@<IP_PUBLIQUE>

# Upload les deux scripts
scp -i ta-cle.pem 01-wireguard-install.sh 02-wireguard-reconnect.sh ec2-user@<IP_PUBLIQUE>:/home/ec2-user/

# Copie le script de reconnexion dans /root (nécessaire pour l'install)
sudo cp 02-wireguard-reconnect.sh /root/

# Lance l'installation
sudo bash 01-wireguard-install.sh
```

Le script affiche un **QR code** (pour mobile) et la **config texte** (pour PC) à la fin de l'installation.

### Après chaque redémarrage de l'instance

La mise à jour de l'IP se fait **automatiquement** au boot via un service systemd. Pour récupérer la nouvelle config :

```bash
ssh -i ta-cle.pem ec2-user@<NOUVELLE_IP>

# QR code pour mobile
sudo wg-reconnect --qr

# Config texte pour PC
sudo wg-reconnect --conf

# Les deux
sudo wg-reconnect
```

Ou récupère directement le fichier :

```bash
scp -i ta-cle.pem ec2-user@<NOUVELLE_IP>:/root/wireguard-clients/client.conf .
```

### Gestion de l'instance

```bash
# Démarrer (via AWS CLI)
aws ec2 start-instances --instance-ids i-xxxxxxxxx

# Stopper
aws ec2 stop-instances --instance-ids i-xxxxxxxxx
```

## Option 2 — Lightsail avec Ubuntu 24.04

Setup clé en main pour Lightsail avec installation automatique au lancement.

### Création de l'instance

1. Dans la console Lightsail, clique **Create instance**
2. Choisis ta région et ta zone
3. Sélectionne **Ubuntu 24.04 LTS**
4. Colle le contenu de `lightsail-wireguard-launch-script.sh` dans le champ **Launch Script**
5. Choisis ton plan (512 Mo suffit)
6. Crée l'instance

### Configuration réseau

Dans l'onglet **Networking** de ton instance Lightsail, ajoute une règle :
- **Application** : Custom
- **Protocol** : UDP
- **Port** : 51820

### Récupérer la config client

```bash
ssh user@<IP_LIGHTSAIL>

# QR code pour mobile
sudo qrencode -t ansiutf8 < /root/client-wireguard.conf

# Config texte pour PC
sudo cat /root/client-wireguard.conf
```

## Configuration des clients

### Mobile (iOS / Android)

1. Installe l'app **WireGuard**
2. Appuie sur **+** puis **Scanner un QR code**
3. Scanne le QR code affiché par le script
4. Active le tunnel

### PC (Windows / Mac / Linux)

1. Installe [WireGuard](https://www.wireguard.com/install/)
2. Importe le fichier `client.conf` téléchargé via SCP
3. Active le tunnel

## Coûts estimés

| Setup | Coût mensuel |
|-------|-------------|
| EC2 t3.micro (free tier, 1ère année) | ~0.08$ (stockage seul) |
| EC2 t2.nano 24/7 | ~4.26$ |
| EC2 t2.nano 24/7 + Elastic IP | ~4.26$ (IP gratuite si instance active) |
| EC2 stoppé + Elastic IP | ~3.68$ |
| Lightsail 512 Mo | 5$/mois fixe |

## Sécurité

- Les clés privées sont stockées dans `/etc/wireguard/` et `/root/wireguard-clients/` avec permissions `600`
- Le trafic est chiffré de bout en bout via WireGuard (ChaCha20, Curve25519)
- Une PresharedKey est utilisée pour une protection supplémentaire contre les attaques quantiques
- Le DNS est configuré sur Cloudflare (`1.1.1.1`) par défaut

## Dépannage

**WireGuard ne démarre pas**
```bash
sudo systemctl status wg-quick@wg0
sudo journalctl -u wg-quick@wg0
```

**Pas de connexion après redémarrage EC2**
```bash
# Vérifie que l'IP a bien été mise à jour
sudo wg-reconnect
# Vérifie que le Security Group autorise UDP 51820
```

**Le QR code ne s'affiche pas correctement**
```bash
# Agrandis ton terminal ou utilise la config texte
sudo wg-reconnect --conf
```

## Licence

MIT
