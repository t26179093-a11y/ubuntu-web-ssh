# Base Image
FROM ubuntu:24.04

# Install dependencies
RUN apt update && apt install -y \
    curl \
    tar \
    ca-certificates \
    bash \
    && rm -rf /var/lib/apt/lists/*

# Install sshx
RUN curl -L https://s3.amazonaws.com/sshx/sshx-x86_64-unknown-linux-musl.tar.gz \
    | tar -xz -C /usr/local/bin && chmod +x /usr/local/bin/sshx

# Öffne Port für Render
EXPOSE 2222

# Starte sshx und halte Container aktiv
CMD bash -c "sshx run & tail -f /dev/null"
