# Dockerfile — stabile 24/7-Variante (Web Service, Port 8080)
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Pakete — curl, adduser/sudo, python3 für HTTP-Server, tar, ca-certificates
RUN apt-get update && apt-get install -y \
    curl \
    adduser \
    sudo \
    python3 \
    python3-pip \
    tar \
    ca-certificates \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Admin-User (optional)
RUN useradd -m admin && echo "admin:admin" | chpasswd && usermod -aG sudo admin

# Install sshx binary (non-interactive)
RUN curl -L https://s3.amazonaws.com/sshx/sshx-x86_64-unknown-linux-musl.tar.gz \
    | tar -xz -C /usr/local/bin && chmod +x /usr/local/bin/sshx

# Create startup script
RUN mkdir -p /opt && \
    cat > /opt/start.sh <<'EOF' && chmod +x /opt/start.sh
#!/bin/bash
set -e

# Ensure log dir exists
mkdir -p /var/log

# Start sshx in background, capture output to log
# Use plain 'sshx' (no 'run') because some versions don't accept 'run'
/usr/local/bin/sshx > /var/log/sshx.log 2>&1 &

# Give sshx a second to write link line
sleep 2

# Show tail of sshx log on container stdout as well (optional)
# but we exec the HTTP server as PID 1 so Render sees port open
tail -n +1 -F /var/log/sshx.log &

# Start simple HTTP server on 0.0.0.0:8080 in foreground (Render needs a listening port)
exec python3 -m http.server 8080 --bind 0.0.0.0
EOF

# Expose port so Render recognizes a web service
EXPOSE 8080

# Start command
CMD ["/bin/bash", "/opt/start.sh"]
