# --- Basis Ubuntu 24.04 ---
FROM ubuntu:24.04

# --- Vorbereitung & Update ---
RUN apt-get update && apt-get install -y curl sudo bash coreutils && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# --- Benutzer "admin" mit sudo ---
RUN useradd -m admin && echo "admin:admin" | chpasswd && adduser admin sudo

# --- sshx installieren ---
RUN curl -L https://s3.amazonaws.com/sshx/sshx-x86_64-unknown-linux-musl.tar.gz \
    | tar -xz -C /usr/local/bin && chmod +x /usr/local/bin/sshx

# --- Dummy-Port offen halten, damit Render den VPS nicht stoppt ---
RUN echo '#!/bin/bash\nwhile true; do echo "alive"; sleep 60; done' > /fake_server.sh && chmod +x /fake_server.sh

# --- Startscript: startet sshx + Dummyserver ---
CMD bash -c "/usr/local/bin/sshx | tee /var/log/sshx.log & /fake_server.sh"

# --- Fake-Port, damit Render den Service als "aktiv" erkennt ---
EXPOSE 8080
