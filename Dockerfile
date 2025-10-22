# === Dockerfile for sshx 24/7 VPS ===
FROM ubuntu:24.04

# Disable interactive apt stuff
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt update && apt install -y \
    curl \
    tar \
    ca-certificates \
    bash \
    && rm -rf /var/lib/apt/lists/*

# Download and install sshx manually
RUN curl -L https://s3.amazonaws.com/sshx/sshx-x86_64-unknown-linux-musl.tar.gz \
    | tar -xz -C /usr/local/bin && chmod +x /usr/local/bin/sshx

# Open port for Render (optional)
EXPOSE 2222

# Run sshx in background forever
CMD bash -c "sshx > /var/log/sshx.log 2>&1 & tail -f /var/log/sshx.log"
