#!/usr/bin/env bash
# vm.sh - Einfaches QEMU VM Manager Script
# Unterstützt: create / start / stop / delete / list / show
# OS: ubuntu22, ubuntu24, debian11, debian12, debian13

set -euo pipefail
BASE_DIR="${HOME}/vms"
QEMU_BIN="$(command -v qemu-system-x86_64 || true)"
IMG_TOOL="$(command -v qemu-img || true)"
CLOUD_LOCALDS="$(command -v cloud-localds || true)"

usage() {
  cat <<EOF
Usage: $0 <command> [options]

Commands:
  create        Interaktiver Assistent zum Erstellen einer neuen VM
  start NAME    Startet VM mit NAME (background)
  stop NAME     Stoppt VM mit NAME
  delete NAME   Stoppt (falls läuft) & löscht VM NAme
  list          Listet vorhandene VMs
  show NAME     Zeigt VM-Konfig an
  help          Diese Hilfe

Beispiele:
  $0 create
  $0 start myvm
  $0 stop myvm
  $0 delete myvm
  $0 list
EOF
  exit 1
}

ensure_tools() {
  if [ -z "$QEMU_BIN" ] || [ -z "$IMG_TOOL" ] || [ -z "$CLOUD_LOCALDS" ]; then
    echo "Fehler: Benötigte Tools fehlen. Bitte installieren:"
    echo "  sudo apt update && sudo apt install -y qemu-kvm qemu-utils cloud-image-utils"
    exit 1
  fi
}

# Map short name -> image URL and preferred container format
os_info() {
  case "$1" in
    ubuntu22)
      echo "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
      ;;
    ubuntu24)
      echo "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
      ;;
    debian11)
      echo "https://cdimage.debian.org/cdimage/cloud/bullseye/latest/debian-11-genericcloud-amd64.qcow2"
      ;;
    debian12)
      echo "https://cdimage.debian.org/cdimage/cloud/bookworm/latest/debian-12-genericcloud-amd64.qcow2"
      ;;
    debian13)
      echo "https://cdimage.debian.org/cdimage/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2"
      ;;
    *)
      echo ""
      ;;
  esac
}

vm_dir() { echo "${BASE_DIR}/$1"; }
vm_cfg() { echo "$(vm_dir "$1")/vm.conf"; }
vm_pidfile() { echo "$(vm_dir "$1")/vm.pid"; }
vm_log() { echo "$(vm_dir "$1")/run.log"; }

# create interactive
create_vm() {
  ensure_tools
  read -rp "VM-Name (klein, keine Leerzeichen): " NAME
  if [ -z "$NAME" ]; then echo "Name leer. Abbruch."; exit 1; fi
  DIR="$(vm_dir "$NAME")"
  if [ -d "$DIR" ]; then echo "VM '$NAME' existiert bereits."; exit 1; fi
  mkdir -p "$DIR"

  echo "Wähle OS:"
  echo " 1) Ubuntu 22.04 (ubuntu22)"
  echo " 2) Ubuntu 24.04 (ubuntu24)"
  echo " 3) Debian 11 (debian11)"
  echo " 4) Debian 12 (debian12)"
  echo " 5) Debian 13 (debian13)"
  read -rp "Auswahl (1-5): " os_choice
  case "$os_choice" in
    1) OS=ubuntu22;;
    2) OS=ubuntu24;;
    3) OS=debian11;;
    4) OS=debian12;;
    5) OS=debian13;;
    *) echo "Ungültig."; rm -rf "$DIR"; exit 1;;
  esac

  read -rp "RAM in MB (default 2048): " RAM
  RAM=${RAM:-2048}
  read -rp "CPU-Kerne (default 2): " CPU
  CPU=${CPU:-2}
  read -rp "Disk Größe in GB für Haupt-Image (default 20): " DISK
  DISK=${DISK:-20}
  read -rp "Extra Disk Größe in GB (0 = none) (default 0): " EXTRA
  EXTRA=${EXTRA:-0}
  read -rp "Root-Passwort (default 'test123'): " PASS
  PASS=${PASS:-test123}

  # Resolve URL
  URL="$(os_info "$OS")"
  if [ -z "$URL" ]; then echo "OS URL nicht gefunden."; rm -rf "$DIR"; exit 1; fi

  IMG_NAME="${DIR}/${NAME}.img"
  SEED_NAME="${DIR}/seed.img"
  META_NAME="${DIR}/meta-data"
  USERDATA="${DIR}/user-data"

  echo "Herunterladen: $URL ..."
  wget -O "$IMG_NAME" "$URL"

  echo "Erweitere Image auf ${DISK}G ..."
  # convert to qcow2 if not already qcow2 (qemu-img can handle)
  $IMG_TOOL convert -f qcow2 -O qcow2 "$IMG_NAME" "${IMG_NAME}.qcow2" 2>/dev/null || mv "$IMG_NAME" "${IMG_NAME}.qcow2"
  IMG_NAME="${IMG_NAME}.qcow2"
  $IMG_TOOL resize "$IMG_NAME" "${DISK}G"

  # cloud-init user-data
  cat > "$USERDATA" <<EOF
#cloud-config
hostname: ${NAME}
manage_etc_hosts: true
users:
  - name: root
    lock_passwd: false
    plain_text_passwd: '${PASS}'
    shell: /bin/bash
ssh_pwauth: true
chpasswd:
  list: |
     root:${PASS}
  expire: False
EOF

  cat > "$META_NAME" <<EOF
instance-id: iid-${NAME}
local-hostname: ${NAME}
EOF

  echo "Erstelle seed image..."
  $CLOUD_LOCALDS "$SEED_NAME" "$USERDATA" "$META_NAME"

  if [ "$EXTRA" -gt 0 ]; then
    echo "Erstelle extra.img (${EXTRA}G)..."
    $IMG_TOOL create -f qcow2 "${DIR}/extra.img" "${EXTRA}G"
  fi

  # save config
  cat > "$(vm_cfg "$NAME")" <<EOF
NAME=${NAME}
OS=${OS}
IMG=${IMG_NAME}
SEED=${SEED_NAME}
EXTRA=${DIR}/extra.img
RAM=${RAM}
CPU=${CPU}
DISK=${DISK}
PASS=${PASS}
EOF

  echo "VM '$NAME' erstellt in $DIR"
  echo "Benutze: ./vm.sh start $NAME"
}

start_vm() {
  NAME="$1"
  CFG_FILE="$(vm_cfg "$NAME")"
  if [ ! -f "$CFG_FILE" ]; then echo "VM '$NAME' existiert nicht."; exit 1; fi
  # shellcheck source=/dev/null
  source "$CFG_FILE"

  DIR="$(vm_dir "$NAME")"
  PIDFILE="$(vm_pidfile "$NAME")"
  LOGFILE="$(vm_log "$NAME")"

  if [ -f "$PIDFILE" ]; then
    if pidof_file="$(cat "$PIDFILE" 2>/dev/null)" && kill -0 "$pidof_file" 2>/dev/null; then
      echo "VM '$NAME' läuft bereits (PID $(cat "$PIDFILE"))."
      exit 0
    else
      echo "Alte PID-Datei entfernen."
      rm -f "$PIDFILE"
    fi
  fi

  # Choose qemu flags
  KVM_FLAGS=""
  if [ -e /dev/kvm ]; then
    KVM_FLAGS="-enable-kvm -cpu host"
    echo "KVM verfügbar: using KVM acceleration"
  else
    echo "⚠️ KVM nicht verfügbar - QEMU läuft software-emuliert."
  fi

  # Build drive list
  DRIVE_MAIN="-drive file=${IMG},if=virtio,format=qcow2,cache=writeback,aio=threads"
  DRIVE_SEED="-drive file=${SEED},if=virtio,format=raw"
  DRIVE_EXTRA=""
  if [ -f "${EXTRA}" ]; then
    DRIVE_EXTRA="-drive file=${EXTRA},if=virtio,format=qcow2"
  fi

  # Daemonize with pidfile
  echo "Starte QEMU (PID wird in $PIDFILE geschrieben). Log: $LOGFILE"
  mkdir -p "$DIR"
  # Start qemu
  "$QEMU_BIN" \
    $KVM_FLAGS \
    -smp "$CPU" \
    -m "$RAM" \
    $DRIVE_MAIN \
    $DRIVE_SEED \
    $DRIVE_EXTRA \
    -nographic \
    -boot c \
    -daemonize \
    -pidfile "$PIDFILE" \
    >"$LOGFILE" 2>&1

  sleep 1
  if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "VM '$NAME' gestartet. PID=$(cat "$PIDFILE")"
  else
    echo "Fehler: VM konnte nicht gestartet werden. Log ausgeben:"
    echo "------ LOG ------"
    sed -n '1,200p' "$LOGFILE" || true
    echo "-----------------"
    exit 1
  fi
}

stop_vm() {
  NAME="$1"
  PIDFILE="$(vm_pidfile "$NAME")"
  if [ ! -f "$PIDFILE" ]; then
    echo "Keine PID-Datei für $NAME gefunden."
    # try pkill fallback
    pkill -f "qemu-system-x86_64.*${NAME}" || true
    echo "Fallback: pkill versucht."
    return
  fi
  PID=$(cat "$PIDFILE")
  if kill -0 "$PID" 2>/dev/null; then
    echo "Stopping VM '$NAME' (PID $PID)..."
    kill "$PID"
    sleep 1
    if kill -0 "$PID" 2>/dev/null; then
      echo "PID noch aktiv, sende SIGKILL..."
      kill -9 "$PID" || true
    fi
    rm -f "$PIDFILE"
    echo "VM stopped."
  else
    echo "PID $PID läuft nicht. Entferne PID-Datei."
    rm -f "$PIDFILE"
  fi
}

delete_vm() {
  NAME="$1"
  DIR="$(vm_dir "$NAME")"
  if [ -d "$DIR" ]; then
    echo "Stopping (if running) and deleting $NAME..."
    stop_vm "$NAME" || true
    rm -rf "$DIR"
    echo "VM $NAME gelöscht."
  else
    echo "VM $NAME nicht gefunden."
  fi
}

list_vms() {
  mkdir -p "$BASE_DIR"
  echo "VMs in $BASE_DIR:"
  for d in "$BASE_DIR"/*; do
    [ -d "$d" ] || continue
    n=$(basename "$d")
    cfg="$(vm_cfg "$n")"
    echo " - $n"
    if [ -f "$cfg" ]; then
      # shellcheck source=/dev/null
      source "$cfg"
      pidf="$(vm_pidfile "$n")"
      status="stopped"
      if [ -f "$pidf" ] && kill -0 "$(cat "$pidf")" 2>/dev/null; then status="running (PID $(cat "$pidf"))"; fi
      echo "    OS: ${OS:-unknown}  RAM: ${RAM:-?}MB  CPU: ${CPU:-?}  Disk: ${DISK:-?}G  Status: $status"
    fi
  done
}

show_vm() {
  NAME="$1"
  CFG="$(vm_cfg "$NAME")"
  if [ -f "$CFG" ]; then
    echo "Config for $NAME:"
    sed -n '1,200p' "$CFG"
  else
    echo "Keine VM mit dem Namen $NAME"
  fi
}

# Main dispatcher
case "${1:-help}" in
  create) create_vm ;;
  start)
    [ -n "${2:-}" ] || { echo "Usage: $0 start NAME"; exit 1; }
    start_vm "$2"
    ;;
  stop)
    [ -n "${2:-}" ] || { echo "Usage: $0 stop NAME"; exit 1; }
    stop_vm "$2"
    ;;
  delete)
    [ -n "${2:-}" ] || { echo "Usage: $0 delete NAME"; exit 1; }
    delete_vm "$2"
    ;;
  list) list_vms ;;
  show)
    [ -n "${2:-}" ] || { echo "Usage: $0 show NAME"; exit 1; }
    show_vm "$2"
    ;;
  help|--help|-h) usage ;;
  *)
    echo "Unknown command: $1"; usage ;;
esac
