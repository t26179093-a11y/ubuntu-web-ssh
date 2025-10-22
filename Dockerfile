# ---- Ubuntu 24.04 ----
FROM ubuntu:24.04

# ---- System aktualisieren & Tools installieren ----
RUN apt update && apt install -y openssh-server ttyd sudo nano curl wget git

# ---- Benutzer erstellen (admin / test123) ----
RUN useradd -m -s /bin/bash admin && echo 'admin:test123' | chpasswd && adduser admin sudo

# ---- SSH & ttyd vorbereiten ----
RUN mkdir /var/run/sshd

# ---- ttyd Port ----
EXPOSE 10000

# ---- Start-Befehl ----
CMD ["bash", "-c", "ttyd -p 10000 login"]
