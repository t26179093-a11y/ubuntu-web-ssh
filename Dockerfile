# Base Image
FROM ubuntu:24.04

# Install dependencies
RUN apt update && apt install -y \
    curl \
    tar \
    ca-certificates \
    bash \
    && rm -rf /var/lib/apt/lists/*

# Download und installieren von sshx
RUN curl -L https://s3.amazonaws.com/sshx/sshx-x86_64-unknown-linux-musl.tar.gz \
    | tar -xz -C /usr/local/bin

# executable permissions
RUN chmod +x /usr/local/bin/sshx

# Port freigeben
EXPOSE 2222

# Default Command starten sshx auf Port 2222
CMD ["sshx", "--port", "2222"]
