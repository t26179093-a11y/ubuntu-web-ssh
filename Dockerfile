# Use a base image that supports systemd, for example, Ubuntu
FROM ubuntu:24.04

# Install necessary packages
RUN curl -sSf https://sshx.io/get | sh -s run


