# Use a base image that supports systemd, for example, Ubuntu
FROM ubuntu:24.04

# Install necessary package
RUN apt update
RUN apt upgrade -y
RUN apt install wget -y
RUN apt install git -y
RUN apt install htop -y
RUN apt install sudo -y
RUN apt install curl -y
RUN curl -sSf https://sshx.io/get | sh -s run


