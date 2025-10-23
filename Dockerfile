FROM ubuntu:24.04

RUN apt update && apt install -y curl sudo nano python3 python3-pip

RUN useradd -m admin && echo "admin:admin" | chpasswd && usermod -aG sudo admin

RUN curl -L https://s3.amazonaws.com/sshx/sshx-x86_64-unknown-linux-musl.tar.gz \
    | tar -xz -C /usr/local/bin && chmod +x /usr/local/bin/sshx

RUN mkdir -p /data
COPY start.sh /start.sh
RUN chmod +x /start.sh

CMD ["/start.sh"]
