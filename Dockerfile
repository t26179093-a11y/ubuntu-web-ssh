# Dockerfile — OpenSSH Server für Render (mit persistent /data)
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    openssh-server \
    python3 \
    curl \
    passwd \
    sudo \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Erstelle data-Ordner (soll von Render als Persistent Disk gemountet werden)
RUN mkdir -p /data

# Kopiere Start-Skript
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Expose SSH + HTTP keepalive port
EXPOSE 22 8080

# Startscript
CMD ["/start.sh"]
