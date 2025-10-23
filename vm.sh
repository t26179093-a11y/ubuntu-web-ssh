#!/bin/bash
# ==============================================
# Multi-VM Manager (QEMU) – Ubuntu & Debian Support
# ==============================================

BASE_DIR="$HOME/vms"
mkdir -p "$BASE_DIR"

# === Funktion: VM erstellen ===
create_vm() {
  echo "VM-Name (klein, keine Leerzeichen):"
  read VM_NAME
  VM_DIR="$BASE_DIR/$VM_NAME"
  mkdir -p "$VM_DIR"

  echo "Wähle OS:"
  echo " 1) Ubuntu 22.04 (ubuntu22)"
  echo " 2) Ubuntu 24.04 (ubuntu24)"
  echo " 3) Debian 11 (debian11)"
  echo " 4) Debian 12 (debian12)"
  echo " 5) Debian 13 (debian13)"
  read -p "Auswahl (1-5): " CHOICE

  case $CHOICE in
    1) IMG_URL="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"; OS="ubuntu22";;
    2) IMG_URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"; OS="ubuntu24";;
    3) IMG_URL="https://cdimage.debian.org/cdimage/cloud/bullseye/latest/bullseye-cloud-amd64.img"; OS="debian11";;
    4) IMG_URL="https://cdimage.debian.org/cdimage/cloud/bookworm/latest/bookworm-cloud-amd64.img"; OS="debian12";;
    5) IMG_URL="https://cdimage.debian.org/cdimage/cloud/trixie/latest/trixie-cloud-amd64.img"; OS="debian13";;
    *) echo "Ungültige Auswahl."; exit 1;;
  esac

  read -p "RAM in MB (default 2048): " RAM
  RAM=${RAM:-2048}

  read -p "CPU-Kerne (default 2): " CPU
  CPU=${CPU:-2}

  read -p "Disk Größe in GB (default 20): " DISK
  DISK=${DISK:-20}

  read -p "Extra Disk Größe in GB (0 = none) (default 0): " EXDISK
  EXDISK=${EXDISK:-0}

  read -p "Root-Passwort (default 'test123'): " ROOTPW
  ROOTPW=${ROOTPW:-test123}

  echo "📦 Lade OS-Image herunter..."
  wget -O "$VM_DIR/$VM_NAME.img" "$IMG_URL"

  echo "💽 Erweitere Haupt-Image auf ${DISK}G ..."
  qemu-img resize "$VM_DIR/$VM_NAME.img" "${DISK}G"

  echo "⚙️ Erstelle Cloud-Init Dateien ..."
  cat > "$VM_DIR/user-data" <<EOF
#cloud-config
hostname: $VM_NAME
manage_etc_hosts: true
users:
  - name: root
    lock_passwd: false
    plain_text_passwd: '$ROOTPW'
    shell: /bin/bash
ssh_pwauth: true
chpasswd:
  list: |
     root:$ROOTPW
  expire: False
EOF

  cat > "$VM_DIR/meta-data" <<EOF
instance-id: iid-$VM_NAME
local-hostname: $VM_NAME
EOF

  cloud-localds "$VM_DIR/seed.img" "$VM_DIR/user-data" "$VM_DIR/meta-data"

  if [ "$EXDISK" -gt 0 ]; then
    echo "💾 Erstelle extra Disk (${EXDISK}G)..."
    qemu-img create -f qcow2 "$VM_DIR/extra.img" "${EXDISK}G"
  fi

  echo "OS=$OS" > "$VM_DIR/config.txt"
  echo "RAM=$RAM" >> "$VM_DIR/config.txt"
  echo "CPU=$CPU" >> "$VM_DIR/config.txt"
  echo "DISK=$DISK" >> "$VM_DIR/config.txt"
  echo "ROOTPW=$ROOTPW" >> "$VM_DIR/config.txt"

  echo "✅ VM '$VM_NAME' erstellt in $VM_DIR"
  echo "➡️  Starte mit: ./vm.sh start $VM_NAME"
}

# === Funktion: VM starten ===
start_vm() {
  VM_NAME="$1"
  MODE="$2"
  VM_DIR="$BASE_DIR/$VM_NAME"

  if [ ! -d "$VM_DIR" ]; then
    echo "❌ VM '$VM_NAME' existiert nicht."
    exit 1
  fi

  if [ -f "$VM_DIR/vm.pid" ]; then
    echo "⚠️ VM '$VM_NAME' scheint bereits zu laufen (PID-Datei existiert)."
    exit 1
  fi

  RAM=$(grep RAM "$VM_DIR/config.txt" | cut -d= -f2)
  CPU=$(grep CPU "$VM_DIR/config.txt" | cut -d= -f2)

  echo "⚙️ Starte VM '$VM_NAME' mit $CPU CPU(s) und $RAM MB RAM ..."

  if [ -e /dev/kvm ]; then
    KVM_OPT="-enable-kvm"
  else
    echo "⚠️ KVM nicht verfügbar - QEMU läuft software-emuliert."
    KVM_OPT=""
  fi

  IMG_FILE="$VM_DIR/$VM_NAME.img"
  SEED_FILE="$VM_DIR/seed.img"
  EXTRA_FILE="$VM_DIR/extra.img"

  if [ "$MODE" == "--log" ]; then
    echo "📝 Log-Modus aktiv – Ausgabe in $VM_DIR/run.log"
    nohup qemu-system-x86_64 \
      -m "$RAM" \
      -smp "$CPU" \
      $KVM_OPT \
      -drive file="$IMG_FILE",if=virtio,format=raw,cache=writeback,aio=threads \
      -drive file="$SEED_FILE",if=virtio,format=raw \
      -drive file="$EXTRA_FILE",if=virtio,format=qcow2 \
      -boot c \
      -nographic > "$VM_DIR/run.log" 2>&1 &
    echo $! > "$VM_DIR/vm.pid"
    echo "✅ VM '$VM_NAME' läuft jetzt im Hintergrund."
  else
    echo "💻 Starte interaktive Konsole – (STRG + A dann X zum Beenden)"
    qemu-system-x86_64 \
      -m "$RAM" \
      -smp "$CPU" \
      $KVM_OPT \
      -drive file="$IMG_FILE",if=virtio,format=raw,cache=writeback,aio=threads \
      -drive file="$SEED_FILE",if=virtio,format=raw \
      -drive file="$EXTRA_FILE",if=virtio,format=qcow2 \
      -serial mon:stdio \
      -boot c
  fi
}

# === Funktion: VM stoppen ===
stop_vm() {
  VM_NAME="$1"
  VM_DIR="$BASE_DIR/$VM_NAME"
  PID_FILE="$VM_DIR/vm.pid"
  if [ ! -f "$PID_FILE" ]; then
    echo "❌ Keine laufende VM '$VM_NAME' gefunden."
    exit 1
  fi
  kill "$(cat "$PID_FILE")" && rm -f "$PID_FILE"
  echo "🛑 VM '$VM_NAME' wurde gestoppt."
}

# === Funktion: VM löschen ===
delete_vm() {
  VM_NAME="$1"
  read -p "⚠️ Bist du sicher, dass du '$VM_NAME' löschen willst? (yes/no): " CONFIRM
  if [ "$CONFIRM" != "yes" ]; then
    echo "❌ Abgebrochen."
    exit 0
  fi
  rm -rf "$BASE_DIR/$VM_NAME"
  echo "🗑️  VM '$VM_NAME' gelöscht."
}

# === Funktion: VMs auflisten ===
list_vms() {
  echo "📋 Verfügbare VMs:"
  for VM in $(ls "$BASE_DIR"); do
    if [ -f "$BASE_DIR/$VM/config.txt" ]; then
      RAM=$(grep RAM "$BASE_DIR/$VM/config.txt" | cut -d= -f2)
      CPU=$(grep CPU "$BASE_DIR/$VM/config.txt" | cut -d= -f2)
      echo " - $VM (RAM: ${RAM}MB, CPU: ${CPU})"
    fi
  done
}

# === Menü ===
case "$1" in
  create) create_vm ;;
  start) start_vm "$2" "$3" ;;
  stop) stop_vm "$2" ;;
  delete) delete_vm "$2" ;;
  list) list_vms ;;
  *) echo "Verwendung: ./vm.sh {create|start|stop|delete|list}" ;;
esac
