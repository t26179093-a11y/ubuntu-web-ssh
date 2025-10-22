#!/bin/bash
# ==============================================
# QEMU Multi-Distro VM mit KVM-Optimierung & schnellerem Boot
# ==============================================

set -e
echo "🚀 Starte QEMU Multi-Distro VM Installer ..."

# === 1. Abhängigkeiten installieren ===
sudo apt update -y
sudo apt install -y qemu-kvm qemu-utils cloud-utils wget unzip git openssh-client ovmf

# === 2. Arbeitsverzeichnis ===
mkdir -p ~/vm
cd ~/vm

# === 3. Systemauswahl ===
echo ""
echo "=============================================="
echo " 🧠 Wähle dein Betriebssystem:"
echo " 1) Ubuntu 22.04 (Jammy)"
echo " 2) Ubuntu 24.04 (Noble)"
echo " 3) Debian 11 (Bullseye)"
echo " 4) Debian 12 (Bookworm)"
echo " 5) Debian 13 (Trixie)"
echo " 6) Kali Linux (Rolling)"
echo " 7) Rocky Linux 9"
echo "=============================================="
read -p "👉 Deine Wahl (1-7): " choice

case $choice in
  1)
    IMG_URL="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
    IMG_NAME="ubuntu22.img"
    OS_NAME="Ubuntu 22.04"
    ;;
  2)
    IMG_URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
    IMG_NAME="ubuntu24.img"
    OS_NAME="Ubuntu 24.04"
    ;;
  3)
    IMG_URL="https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-genericcloud-amd64.qcow2"
    IMG_NAME="debian11.img"
    OS_NAME="Debian 11"
    ;;
  4)
    IMG_URL="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2"
    IMG_NAME="debian12.img"
    OS_NAME="Debian 12"
    ;;
  5)
    IMG_URL="https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2"
    IMG_NAME="debian13.img"
    OS_NAME="Debian 13"
    ;;
  6)
    IMG_URL="https://cdimage.kali.org/kali-cloud/kali-latest-cloud-amd64.qcow2"
    IMG_NAME="kali.img"
    OS_NAME="Kali Linux"
    ;;
  7)
    IMG_URL="https://download.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud.latest.x86_64.qcow2"
    IMG_NAME="rocky9.img"
    OS_NAME="Rocky Linux 9"
    ;;
  *)
    echo "❌ Ungültige Auswahl. Abbruch."
    exit 1
    ;;
esac

# === 4. Image laden und optional in raw konvertieren ===
if [ ! -f $IMG_NAME ]; then
  echo "📦 Lade $OS_NAME Cloud-Image herunter ..."
  wget -O $IMG_NAME $IMG_URL
  echo "💽 Erweitere Image auf 80GB ..."
  qemu-img resize $IMG_NAME 80G
else
  echo "✅ $OS_NAME-Image bereits vorhanden."
fi

# Optional: raw-Format für maximale Geschwindigkeit
RAW_IMG="${IMG_NAME%.img}.raw"
if [ ! -f $RAW_IMG ]; then
  echo "⚡ Konvertiere $IMG_NAME in raw-Format für schnelleren Boot ..."
  qemu-img convert -O raw $IMG_NAME $RAW_IMG
fi

# === 5. Cloud-Init Konfiguration ===
cat > user-data <<EOF
#cloud-config
hostname: myvm
manage_etc_hosts: true
users:
  - name: root
    lock_passwd: false
    plain_text_passwd: 'test123'
    shell: /bin/bash
ssh_pwauth: true
chpasswd:
  list: |
     root:test123
  expire: False
EOF

cat > meta-data <<EOF
instance-id: iid-local01
local-hostname: myvm
EOF

echo "⚙️  Erstelle seed.img ..."
cloud-localds seed.img user-data meta-data

# === 6. Hardware prüfen ===
if [ -e /dev/kvm ]; then
  echo "✅ KVM-Unterstützung erkannt – Hardwarebeschleunigung aktiv!"
  KVM_FLAG="-enable-kvm -cpu host"
else
  echo "⚠️  Keine KVM-Unterstützung erkannt – VM läuft langsamer."
  KVM_FLAG=""
fi

# === 7. Ressourcen automatisch anpassen (75 % Nutzung) ===
TOTAL_RAM=$(free -m | awk '/Mem:/ {print $2}')
USE_RAM=$((TOTAL_RAM * 75 / 100))
TOTAL_CPU=$(nproc)
USE_CPU=$((TOTAL_CPU - 1))
if [ $USE_CPU -lt 1 ]; then USE_CPU=1; fi
echo "💡 Nutze $USE_CPU CPU-Kerne und ${USE_RAM}MB RAM (75 % deines Systems)."

# === 8. Zusätzliche Festplatte prüfen oder erstellen ===
if [ ! -f extra.img ]; then
  echo "💾 Erstelle zusätzliche Festplatte (20G) ..."
  qemu-img create -f qcow2 extra.img 20G
else
  echo "✅ Zusätzliche Festplatte extra.img bereits vorhanden."
fi

# === 9. VM starten (optimiert für schnellen Boot) ===
echo "💻 Starte $OS_NAME VM ..."
qemu-system-x86_64 \
  $KVM_FLAG \
  -smp cores=$USE_CPU,threads=1 \
  -m $USE_RAM \
  -drive file=$RAW_IMG,if=virtio,format=raw,cache=writeback,aio=native \
  -drive file=extra.img,if=virtio,format=qcow2,cache=writeback,aio=native \
  -drive file=seed.img,if=virtio,format=raw \
  -nographic \
  -boot order=c
