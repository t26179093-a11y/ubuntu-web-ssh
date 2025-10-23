#!/bin/bash
# ==========================================
# 🧠 All-in-One VM Manager (QEMU + sshx.io)
# ==========================================
# Unterstützt Ubuntu 22.04 / 24.04 / Debian 11–13

BASE_DIR="/root/vms"
mkdir -p "$BASE_DIR"

create_vm() {
  echo -n "VM-Name (klein, keine Leerzeichen): "
  read VM_NAME
  mkdir -p "$BASE_DIR/$VM_NAME"

  echo "Wähle OS:"
  echo " 1) Ubuntu 22.04"
  echo " 2) Ubuntu 24.04"
  echo " 3) Debian 11"
  echo " 4) Debian 12"
  echo " 5) Debian 13"
  read -p "Auswahl (1-5): " OS_CHOICE

  case $OS_CHOICE in
    1) IMG_URL="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img" ;;
    2) IMG_URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img" ;;
    3) IMG_URL="https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-genericcloud-amd64.qcow2" ;;
    4) IMG_URL="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2" ;;
    5) IMG_URL="https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2" ;;
    *) echo "Ungültige Auswahl"; exit 1 ;;
  esac

  read -p "RAM in MB (default 2048): " RAM
  RAM=${RAM:-2048}
  read -p "CPU-Kerne (default 2): " CPU
  CPU=${CPU:-2}
  read -p "Disk Größe in GB (default 20): " DISK
  DISK=${DISK:-20}
  read -p "Extra Disk Größe in GB (0 = keine): " EXTRA
  EXTRA=${EXTRA:-0}
  read -p "Root-Passwort (default test123): " PASSWD
  PASSWD=${PASSWD:-test123}

  echo "Lade OS-Image herunter..."
  wget -O "$BASE_DIR/$VM_NAME/$VM_NAME.img" "$IMG_URL"

  echo "Erweitere Image auf ${DISK}G ..."
  qemu-img resize "$BASE_DIR/$VM_NAME/$VM_NAME.img" ${DISK}G

  echo "Erstelle Cloud-Init Konfiguration..."
  cat > "$BASE_DIR/$VM_NAME/user-data" <<EOF
#cloud-config
hostname: $VM_NAME
manage_etc_hosts: true
users:
  - name: root
    lock_passwd: false
    plain_text_passwd: '$PASSWD'
    shell: /bin/bash
ssh_pwauth: true
chpasswd:
  list: |
     root:$PASSWD
  expire: False
EOF

  echo "instance-id: iid-$VM_NAME" > "$BASE_DIR/$VM_NAME/meta-data"

  cloud-localds "$BASE_DIR/$VM_NAME/seed.img" "$BASE_DIR/$VM_NAME/user-data" "$BASE_DIR/$VM_NAME/meta-data"

  if [ "$EXTRA" -gt 0 ]; then
    echo "Erstelle extra.img (${EXTRA}G)..."
    qemu-img create -f qcow2 "$BASE_DIR/$VM_NAME/extra.img" ${EXTRA}G
  fi

  echo "RAM=$RAM" > "$BASE_DIR/$VM_NAME/config.txt"
  echo "CPU=$CPU" >> "$BASE_DIR/$VM_NAME/config.txt"

  echo "✅ VM '$VM_NAME' erstellt."
  echo "Start mit: ./vm.sh start $VM_NAME"
}

start_vm() {
  VM_NAME="$1"
  MODE="$2"
  VM_DIR="$BASE_DIR/$VM_NAME"

  if [ ! -d "$VM_DIR" ]; then
    echo "❌ VM '$VM_NAME' existiert nicht."
    exit 1
  fi

  RAM=$(grep RAM "$VM_DIR/config.txt" | cut -d= -f2)
  CPU=$(grep CPU "$VM_DIR/config.txt" | cut -d= -f2)
  IMG_FILE="$VM_DIR/$VM_NAME.img"
  SEED_FILE="$VM_DIR/seed.img"
  EXTRA_FILE="$VM_DIR/extra.img"

  if [ -e /dev/kvm ]; then
    KVM_OPT="-enable-kvm"
  else
    echo "⚠️ KVM nicht verfügbar - läuft software-emuliert."
    KVM_OPT=""
  fi

  echo "Starte VM '$VM_NAME' mit $CPU CPU(s), $RAM MB RAM ..."

  CMD="qemu-system-x86_64 \
    -m $RAM \
    -smp $CPU \
    $KVM_OPT \
    -drive file=$IMG_FILE,if=virtio,format=raw,cache=writeback,aio=threads \
    -drive file=$SEED_FILE,if=virtio,format=raw \
    $( [ -f $EXTRA_FILE ] && echo "-drive file=$EXTRA_FILE,if=virtio,format=qcow2" ) \
    -boot c \
    -nographic \
    -serial mon:stdio"

  if [ "$MODE" == "--web" ]; then
    echo "🌐 Starte sshx.io Web-Terminal..."
    curl -fsSL https://sshx.io/get | sh -s -- bash -c "$CMD"
  else
    echo "💻 Interaktiver Modus – (STRG + A dann X zum Beenden)"
    eval "$CMD"
  fi
}

stop_vm() {
  VM_NAME="$1"
  PID_FILE="$BASE_DIR/$VM_NAME/vm.pid"
  if [ -f "$PID_FILE" ]; then
    kill "$(cat "$PID_FILE")"
    rm -f "$PID_FILE"
    echo "🛑 VM '$VM_NAME' gestoppt."
  else
    echo "❌ Keine laufende VM gefunden."
  fi
}

delete_vm() {
  VM_NAME="$1"
  read -p "⚠️ VM '$VM_NAME' wirklich löschen? (y/N): " CONFIRM
  if [[ "$CONFIRM" == "y" || "$CONFIRM" == "Y" ]]; then
    rm -rf "$BASE_DIR/$VM_NAME"
    echo "🗑️ VM '$VM_NAME' gelöscht."
  else
    echo "Abgebrochen."
  fi
}

list_vms() {
  echo "📦 Verfügbare VMs:"
  ls "$BASE_DIR"
}

case "$1" in
  create) create_vm ;;
  start) start_vm "$2" "$3" ;;
  stop) stop_vm "$2" ;;
  delete) delete_vm "$2" ;;
  list) list_vms ;;
  *) echo "Verwendung: ./vm.sh {create|start|stop|delete|list}" ;;
esac
