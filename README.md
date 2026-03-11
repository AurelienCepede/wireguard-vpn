# WireGuard VPN — Scripts d'installation automatique

Scripts Bash pour déployer un serveur VPN WireGuard sur AWS EC2 en quelques minutes.

## Contenu du repo

```
.
├── ec2-amazon-linux/
│   ├── 01-wireguard-install.sh    # Installation initiale (Amazon Linux 2023/EC2)
│   └── 02-wireguard-reconnect.sh  # Mise à jour auto de l'IP après redémarrage
└── README.md
```

## Prérequis

- Un compte AWS avec accès à EC2
- Une paire de clés SSH (ED25519 recommandé)
- L'application WireGuard installée sur ton appareil client ([iOS](https://apps.apple.com/app/wireguard/id1441195209) / [Android](https://play.google.com/store/apps/details?id=com.wireguard.android) / [Windows/Mac/Linux](https://www.wireguard.com/install/))

## EC2 avec Amazon Linux 2023

Setup optimisé pour une instance EC2 à la demande. Amazon Linux est gratuit (pas de surcoût de licence) et nativement optimisé pour AWS.

### Création de l'instance

1. Dans la console AWS, sélectionne ta **région** en haut à droite
2. Lance une instance EC2 :
   - **AMI** : Amazon Linux 2023
   - **Type** : `t3.micro` (free tier) ou `t2.nano` (~0.0058$/h)
   - **Stockage** : gp3
   - **Key Pair** : ED25519
3. Configure le **Security Group** — ajoute une règle Inbound :
   - Type : `Custom UDP`
   - Port : `51820`
   - Source : `0.0.0.0/0`

### Installation

Depuis ta machine locale, upload et lance les scripts :

```bash
# Upload les deux scripts sur l'instance
scp -i ta-cle.pem ec2-amazon-linux/01-wireguard-install.sh ec2-amazon-linux/02-wireguard-reconnect.sh ec2-user@<IP_PUBLIQUE>:/home/ec2-user/

# Connecte-toi en SSH
ssh -i ta-cle.pem ec2-user@<IP_PUBLIQUE>

# Lance l'installation
sudo bash 01-wireguard-install.sh
```

Le script affiche un **QR code** (pour mobile) et la **config texte** (pour PC) à la fin de l'installation.

**Alternative** — Tu peux aussi cloner le repo directement depuis l'instance :

```bash
ssh -i ta-cle.pem ec2-user@<IP_PUBLIQUE>

git clone https://github.com/<ton-username>/wireguard-vpn.git
cd wireguard-vpn/ec2-amazon-linux
sudo bash 01-wireguard-install.sh
```

### Après chaque redémarrage de l'instance

La mise à jour de l'IP se fait **automatiquement** au boot via un service systemd. Pour récupérer la nouvelle config, connecte-toi en SSH et lance :

```bash
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
| EC2 t2.nano 2h/jour | ~0.43$ + stockage |

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
