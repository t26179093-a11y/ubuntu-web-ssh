#!/bin/bash
# ==========================================
# ⚡ Fast VM Manager optimized for containers
# Supports Ubuntu 22.04/24.04, Debian 11–13
# Runs fast in containers, Web-Terminal ready (sshx.io)
# ==========================================
BASE_DIR="/root/vms"
mkdir -p "$BASE_DIR"

# -----------------------------
# VM erstellen
# -----------------------------
create_vm() {
  echo -n "VM-Name: "
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

  read -p "RAM in MB (default 4096): " RAM
  RAM=${RAM:-4096}
  read -p "CPU-Kerne (default 2): " CPU
  CPU=${CPU:-2}
  read -p "Disk Größe in GB (default 20): " DISK
  DISK=${DISK:-20}
  read -p "Root-Passwort (default test123): " PASSWD
  PASSWD=${PASSWD:-test123}

  echo "📥 Lade Image..."
  wget -q -O "$BASE_DIR/$VM_NAME/$VM_NAME.img" "$IMG_URL"

  echo "📦 Resize Image auf ${DISK}G..."
  qemu-img resize "$BASE_DIR/$VM_NAME/$VM_NAME.img" ${DISK}G

  echo "⚙️ Erstelle Cloud-Init..."
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

  echo "RAM=$RAM" > "$BASE_DIR/$VM_NAME/config.txt"
  echo "CPU=$CPU" >> "$BASE_DIR/$VM_NAME/config.txt"

  echo "✅ VM '$VM_NAME' erstellt."
}

# -----------------------------
# VM starten
# -----------------------------
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
  IMG="$VM_DIR/$VM_NAME.img"
  SEED="$VM_DIR/seed.img"

  KVM_OPT=""
  if [ -e /dev/kvm ]; then
    KVM_OPT="-enable-kvm"
    echo "✅ KVM verfügbar"
  else
    echo "⚠️ KVM nicht verfügbar, Software-Emulation aktiv"
  fi

  CMD="qemu-system-x86_64 -m $RAM -smp $CPU $KVM_OPT \
    -drive file=$IMG,if=virtio,cache=writeback,aio=threads \
    -drive file=$SEED,if=virtio,format=raw \
    -boot c -nographic -serial mon:stdio -netdev user,id=n1,hostfwd=tcp::2222-:22 -device virtio-net,netdev=n1"

  if [ "$MODE" == "--web" ]; then
    echo "🌐 Starte VM im sshx.io Web-Terminal..."
    curl -fsSL https://sshx.io/get | sh -s -- bash -c "$CMD"
  else
    echo "💻 Interaktive Konsole..."
    eval "$CMD"
  fi
}

# -----------------------------
# VM stoppen
# -----------------------------
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

# -----------------------------
# VM neu starten
# -----------------------------
restart_vm() {
  VM_NAME="$1"
  stop_vm "$VM_NAME"
  sleep 2
  start_vm "$VM_NAME" "--web"
}

# -----------------------------
# VM löschen
# -----------------------------
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

# -----------------------------
# Alle VMs auflisten
# -----------------------------
list_vms() {
  echo "📦 Verfügbare VMs:"
  ls "$BASE_DIR"
}

# -----------------------------
# VM-Info anzeigen
# -----------------------------
info_vm() {
  VM_NAME="$1"
  VM_DIR="$BASE_DIR/$VM_NAME"
  if [ ! -d "$VM_DIR" ]; then
    echo "❌ VM '$VM_NAME' existiert nicht."
    exit 1
  fi

  RAM=$(grep RAM "$VM_DIR/config.txt" | cut -d= -f2)
  CPU=$(grep CPU "$VM_DIR/config.txt" | cut -d= -f2)
  DISK=$(qemu-img info "$VM_DIR/$VM_NAME.img" | grep "virtual size" | awk '{print $3}')
  echo "ℹ️ VM '$VM_NAME' Info:"
  echo "   RAM: ${RAM}MB"
  echo "   CPU: $CPU"
  echo "   Haupt-Disk: $DISK"
}

# -----------------------------
# Main
# -----------------------------
case "$1" in
  create) create_vm ;;
  start) start_vm "$2" "$3" ;;
  stop) stop_vm "$2" ;;
  restart) restart_vm "$2" ;;
  delete) delete_vm "$2" ;;
  list) list_vms ;;
  info) info_vm "$2" ;;
  *) echo "Verwendung: ./vm.sh {create|start|stop|restart|delete|list|info}" ;;
