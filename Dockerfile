FROM ubuntu:24.04

# Basis-Tools installieren
RUN apt update && apt install -y curl sudo nano python3 python3-pip

# Benutzer erstellen mit sudo
RUN useradd -m admin && echo "admin:admin" | chpasswd && usermod -aG sudo admin

# sshx installieren
RUN curl -L https://s3.amazonaws.com/sshx/sshx-x86_64-unknown-linux-musl.tar.gz \
    | tar -xz -C /usr/local/bin && chmod +x /usr/local/bin/sshx

# Starte sshx, damit es dauerhaft läuft
CMD ["bash", "-c", "while true; do sshx serve --port 8080 --root /data; sleep 5; done"]
