# Dockerfile — sshx 24/7 (works on Render / Docker)
FROM ubuntu:24.04

# Nicht-interaktives apt
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt update && apt install -y \
    curl \
    sudo \
    tar \
    ca-certificates \
    bash \
    && rm -rf /var/lib/apt/lists/*

# Install sshx binary directly (stable, non-interactive)
RUN curl -L https://s3.amazonaws.com/sshx/sshx-x86_64-unknown-linux-musl.tar.gz \
    | tar -xz -C /usr/local/bin && chmod +x /usr/local/bin/sshx

# EXPOSE optional for platform detection (Render)
EXPOSE 2222

# Start sshx and keep container alive while streaming its log.
# Note: use plain "sshx" (no "run") because some sshx versions don't accept "run".
# The sshx process prints the share URL to stdout; we capture it in /var/log/sshx.log
CMD bash -c "mkdir -p /var/log && \
             /usr/local/bin/sshx > /var/log/sshx.log 2>&1 & \
             echo '>>> sshx started, streaming /var/log/sshx.log below' && \
             tail -n +1 -F /var/log/sshx.log"
