# Base: Ubuntu 24.04 mit sudo, curl, Docker-Kompatibilität
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Install basics
RUN apt update && apt install -y \
    sudo \
    curl \
    wget \
    tar \
    bash \
    iproute2 \
    ca-certificates \
    apt-transport-https \
    gnupg \
    software-properties-common \
    && rm -rf /var/lib/apt/lists/*

# Add a sudo user (optional, du kannst auch direkt root nutzen)
RUN useradd -m admin && echo "admin:admin" | chpasswd && adduser admin sudo

# Install sshx (for terminal access)
RUN curl -L https://s3.amazonaws.com/sshx/sshx-x86_64-unknown-linux-musl.tar.gz \
    | tar -xz -C /usr/local/bin && chmod +x /usr/local/bin/sshx

# Ports für sshx
EXPOSE 2222

# Start sshx + bleibe online
CMD bash -c "mkdir -p /var/log && \
             /usr/local/bin/sshx > /var/log/sshx.log 2>&1 & \
             echo 'Container läuft mit Root + sudo' && \
             echo 'Log: /var/log/sshx.log' && \
             tail -n +1 -F /var/log/sshx.log"
