FROM ubuntu:24.04

# --- Grundsystem ---
RUN apt update && apt install -y curl sudo nano python3 python3-pip

# --- Admin-User ---
RUN useradd -m admin && echo "admin:admin" | chpasswd && usermod -aG sudo admin

# --- sshx installieren ---
RUN curl -L https://s3.amazonaws.com/sshx/sshx-x86_64-unknown-linux-musl.tar.gz \
    | tar -xz -C /usr/local/bin && chmod +x /usr/local/bin/sshx

# --- Start-Script ---
RUN mkdir -p /data
COPY start.sh /start.sh
RUN chmod +x /start.sh

CMD ["/start.sh"]
