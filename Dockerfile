# === Basis-Image ===
FROM ubuntu:24.04

# === System-Setup ===
RUN apt update && apt install -y \
    curl sudo adduser openssl ca-certificates && \
    apt clean

# === Benutzer "admin" mit sudo ===
RUN useradd -m admin && echo "admin:admin" | chpasswd && usermod -aG sudo admin

# === sshx installieren ===
RUN curl -L https://s3.amazonaws.com/sshx/sshx-x86_64-unknown-linux-musl.tar.gz \
    | tar -xz -C /usr/local/bin && chmod +x /usr/local/bin/sshx

# === Fake-Webserver (für Render-Port-Erkennung) + sshx Start ===
RUN echo '#!/bin/bash\n\
(while true; do echo "alive"; sleep 60; done) &\n\
/usr/local/bin/sshx run &\n\
python3 -m http.server 8080\n' > /start.sh && chmod +x /start.sh

# === Startbefehl ===
CMD ["/bin/bash", "/start.sh"]

# === Port freigeben ===
EXPOSE 8080
