# Ubuntu 24.04 target running systemd as PID 1 with SSH access,
# suitable for Docker Desktop on Apple Silicon (arm64).
FROM ubuntu:24.04

ENV container=docker \
    DEBIAN_FRONTEND=noninteractive

# systemd as init + SSH server + sudo for the Ansible user.
# python3 is required for Ansible to manage Ubuntu 24.04 targets.
# curl is used to verify the deployed API from inside the target.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        systemd \
        systemd-sysv \
        openssh-server \
        sudo \
        python3 \
        python3-apt \
        curl \
    && rm -rf /var/lib/apt/lists/* \
    && systemctl enable ssh \
    && mkdir -p /run/sshd

# Dedicated Ansible management user.
RUN useradd -m -s /bin/bash ansible \
    && mkdir -p /home/ansible/.ssh \
    && chmod 700 /home/ansible/.ssh \
    && chown -R ansible:ansible /home/ansible/.ssh \
    && printf 'ansible ALL=(ALL) NOPASSWD: ALL\n' > /etc/sudoers.d/ansible \
    && chmod 440 /etc/sudoers.d/ansible

# SSH port (published to host port 2222 by setup-target.sh).
EXPOSE 22

# Graceful systemd shutdown.
STOPSIGNAL SIGRTMIN+3

CMD ["/sbin/init"]