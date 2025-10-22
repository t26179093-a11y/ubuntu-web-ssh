FROM ubuntu:24.04

# Abhängigkeiten installieren
RUN apt update && apt install -y curl tar ca-certificates bash && rm -rf /var/lib/apt/lists/*

# SSHX installieren
RUN curl -L https://s3.amazonaws.com/sshx/sshx-x86_64-unknown-linux-musl.tar.gz \
    | tar -xz -C /usr/local/bin
RUN chmod +x /usr/local/bin/sshx
RUN sshx --version

# Dauerhaft aktiv bleiben
# Wir lassen bash in einem Endlosschleifenprozess laufen
CMD ["bash", "-c", "while true; do sleep 1000; done"]
