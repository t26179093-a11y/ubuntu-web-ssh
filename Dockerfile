FROM ubuntu:24.04

# Grundtools
RUN apt update && apt install -y curl sudo nano python3 python3-pip

# User mit sudo
RUN useradd -m admin && echo "admin:admin" | chpasswd && usermod -aG sudo admin

# sshx installieren
RUN curl -L https://s3.amazonaws.com/sshx/sshx-x86_64-unknown-linux-musl.tar.gz \
    | tar -xz -C /usr/local/bin && chmod +x /usr/local/bin/sshx

# Starte sshx einmal, um den Link zu erzeugen und dann zu behalten
CMD bash -c '\
echo "Starte sshx..."; \
LINK_FILE=/data/sshx_link.txt; \
mkdir -p /data; \
if [ -f "$LINK_FILE" ]; then \
  echo "Verwende gespeicherten Link:"; cat "$LINK_FILE"; \
else \
  sshx -o /data/sshx_link.txt >/data/sshx_log.txt 2>&1 & \
  sleep 5; \
  cat /data/sshx_link.txt; \
fi; \
tail -f /data/sshx_log.txt'
