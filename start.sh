#!/bin/bash
set -e

# Pfade
DATA_DIR="/data"
CREDS_FILE="$DATA_DIR/creds.txt"
SSH_LOG="$DATA_DIR/sshd.log"

mkdir -p "$DATA_DIR"

# --- SSH Host Keys persistent machen ---
if [ ! -f "$DATA_DIR/ssh_host_rsa_key" ]; then
  echo "Generating persistent SSH host keys..."
  ssh-keygen -t rsa -b 4096 -f "$DATA_DIR/ssh_host_rsa_key" -N "" >/dev/null 2>&1
  ssh-keygen -t ed25519 -f "$DATA_DIR/ssh_host_ed25519_key" -N "" >/dev/null 2>&1
fi

# Link /etc/ssh keys to /data (overwrite existing)
rm -f /etc/ssh/ssh_host_* 2>/dev/null || true
ln -s "$DATA_DIR/ssh_host_rsa_key" /etc/ssh/ssh_host_rsa_key
ln -s "$DATA_DIR/ssh_host_ed25519_key" /etc/ssh/ssh_host_ed25519_key
ln -s "$DATA_DIR/ssh_host_rsa_key.pub" /etc/ssh/ssh_host_rsa_key.pub
ln -s "$DATA_DIR/ssh_host_ed25519_key.pub" /etc/ssh/ssh_host_ed25519_key.pub

# --- sshd config: erlaube Passwort-Login (unsicher, optional) ---
SSHD_CFG="/etc/ssh/sshd_config"
# backup original
cp -n $SSHD_CFG ${SSHD_CFG}.orig 2>/dev/null || true
# ensure required settings
sed -i 's/^#\?PasswordAuthentication .*$/PasswordAuthentication yes/' $SSHD_CFG || echo "PasswordAuthentication yes" >> $SSHD_CFG
sed -i 's/^#\?PermitRootLogin .*$/PermitRootLogin yes/' $SSHD_CFG || echo "PermitRootLogin yes" >> $SSHD_CFG
sed -i 's/^#\?UsePAM .*$/UsePAM yes/' $SSHD_CFG || echo "UsePAM yes" >> $SSHD_CFG
# ensure port 22 present
grep -q "^Port 22" $SSHD_CFG || echo "Port 22" >> $SSHD_CFG

# --- Erstelle Admin-User (wenn noch nicht vorhanden) ---
USERNAME=${SSH_USER:-admin}
PASSWORD=${SSH_PASS:-admin123}

if ! id -u "$USERNAME" >/dev/null 2>&1; then
  useradd -m -s /bin/bash "$USERNAME"
  echo "$USERNAME:$PASSWORD" | chpasswd
  usermod -aG sudo "$USERNAME"
fi

# Speichere Credentials (falls gewünscht)
echo "username: $USERNAME" > "$CREDS_FILE"
echo "password: $PASSWORD" >> "$CREDS_FILE"
echo "ssh_port: 22" >> "$CREDS_FILE"
# Trage öffentliche IP ein (falls verfügbar)
if command -v curl >/dev/null 2>&1; then
  PUBLIC_IP=$(curl -s ifconfig.me || true)
  echo "public_ip: $PUBLIC_IP" >> "$CREDS_FILE"
fi
echo "NOTE: If this runs behind a load balancer, use the Render service URL/IP displayed in dashboard." >> "$CREDS_FILE"

# set ownership
chown -R root:root "$DATA_DIR"
chmod 600 "$DATA_DIR"/* || true

# --- Start sshd ---
mkdir -p /var/run/sshd
# start sshd in background, write logs to persistent file
/usr/sbin/sshd -f /etc/ssh/sshd_config -D >/dev/null 2>>"$SSH_LOG" &

# --- Start simple HTTP server in foreground so Render sees open port 8080 ---
# create small index showing basic info
cat > /data/index.html <<EOF
<html>
<head><title>Render SSH Service</title></head>
<body>
<h3>Render SSH Service</h3>
<p>SSH user: $USERNAME</p>
<p>SSH pass: $PASSWORD</p>
<p>Port: 22</p>
<p>See /data/creds.txt for details.</p>
</body>
</html>
EOF

# Serve on 8080 in foreground (Render requires a foreground web process)
exec python3 -m http.server 8080 --bind 0.0.0.0
