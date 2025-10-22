# Verwende Ubuntu 24.04 als Basis
FROM ubuntu:24.04

# ===============================
# 1. Abhängigkeiten installieren
# ===============================
RUN apt update && apt install -y \
    curl \
    tar \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# ===============================
# 2. SSHX Binary herunterladen
# ===============================
RUN curl -L https://s3.amazonaws.com/sshx/sshx-x86_64-unknown-linux-musl.tar.gz \
    | tar -xz -C /usr/local/bin

# Binary ausführbar machen
RUN chmod +x /usr/local/bin/sshx

# ===============================
# 3. Test: Version überprüfen
# ===============================
RUN sshx --version

# ===============================
# 4. Standardbefehl beim Containerstart
# ===============================
CMD ["bash"]
