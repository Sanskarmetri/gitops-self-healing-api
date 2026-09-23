#!/usr/bin/env bash
#
# Builds and starts the Docker target that Ansible manages as a normal
# remote Linux host. Generates a throwaway SSH key pair under the local
# hidden .ansible/ directory if one does not already exist.
#
# Usage:  bash setup-target.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

KEY_DIR="${ANSIBLE_DIR}/.ansible"
PRIVATE_KEY="${KEY_DIR}/key"
PUBLIC_KEY="${KEY_DIR}/key.pub"

IMAGE_NAME="gitops-target:latest"
CONTAINER_NAME="gitops-target"

# Host-side published ports (override with env vars if needed).
HOST_SSH_PORT="${HOST_SSH_PORT:-2222}"
HOST_APP_PORT="${HOST_APP_PORT:-8082}"

mkdir -p "${KEY_DIR}"

# Generate a throwaway SSH key pair if it does not exist yet.
if [[ ! -f "${PRIVATE_KEY}" ]]; then
    echo ">> Generating SSH key pair under ${KEY_DIR}"
    ssh-keygen -t ed25519 -N "" -C "ansible@gitops-target" -f "${PRIVATE_KEY}"
else
    echo ">> Reusing existing SSH key pair under ${KEY_DIR}"
fi

echo ">> Building target image ${IMAGE_NAME}"
docker build -t "${IMAGE_NAME}" "${SCRIPT_DIR}"

# Clean up any previous container with the same name.
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo ">> Removing existing container ${CONTAINER_NAME}"
    docker rm -f "${CONTAINER_NAME}"
fi

echo ">> Starting container ${CONTAINER_NAME}"
docker run -d \
    --name "${CONTAINER_NAME}" \
    --hostname "${CONTAINER_NAME}" \
    --privileged \
    --cgroupns=host \
    -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
    --tmpfs /run \
    --tmpfs /run/lock \
    -p "${HOST_SSH_PORT}:22" \
    -p "${HOST_APP_PORT}:8080" \
    "${IMAGE_NAME}"

echo ">> Waiting for SSH to become reachable on port ${HOST_SSH_PORT}..."
for _ in $(seq 1 30); do
    if nc -z 127.0.0.1 "${HOST_SSH_PORT}" 2>/dev/null; then
        break
    fi
    sleep 1
done

echo ">> Installing SSH public key for the ansible user"
# /tmp is a systemd tmpfs inside the container, so use persistent /var/tmp.
docker cp "${PUBLIC_KEY}" "${CONTAINER_NAME}:/var/tmp/authorized_keys"
docker exec "${CONTAINER_NAME}" sh -c '
    mkdir -p /home/ansible/.ssh &&
    mv /var/tmp/authorized_keys /home/ansible/.ssh/authorized_keys &&
    chmod 600 /home/ansible/.ssh/authorized_keys &&
    chmod 700 /home/ansible/.ssh &&
    chown -R ansible:ansible /home/ansible/.ssh
'

echo ""
echo "Target container ready."
echo "  SSH connectivity check:  ssh -i ${PRIVATE_KEY} -p ${HOST_SSH_PORT} ansible@127.0.0.1"
echo "  Application URL after deployment:  http://localhost:${HOST_APP_PORT}/health"
echo ""
echo "Next step:"
echo "  cd ansible && ansible-playbook site.yml"