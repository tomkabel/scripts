#!/usr/bin/env bash

set -e

# Install required OS packages
apt-get update -y
apt-get install -y ca-certificates build-essential libc6 runc lsb-release g++ wget curl git pigz xz-utils unzip jq vim tree openssl openssh-client whiptail tmux make

# Add SSH public key to current user's ~/.ssh/authorized_keys
SSH_PUB_KEY=""
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
if ! grep -qxF "$SSH_PUB_KEY" "$HOME/.ssh/authorized_keys" 2>/dev/null; then
    echo "$SSH_PUB_KEY" >> "$HOME/.ssh/authorized_keys"
    chmod 600 "$HOME/.ssh/authorized_keys"
fi

# Download and install lego if missing
if ! command -v lego >/dev/null 2>&1; then
    LEGO_VERSION="v4.24.0"
    LEGO_URL="https://github.com/go-acme/lego/releases/download/${LEGO_VERSION}/lego_${LEGO_VERSION}_linux_amd64.tar.gz"
    tmp=$(mktemp -d)
    wget "$LEGO_URL" -O "$tmp/lego.tar.gz"
    tar -xzf "$tmp/lego.tar.gz" -C "$tmp"
    mv "$tmp/lego" /usr/local/bin/lego
    chmod +x /usr/local/bin/lego
    rm -rf "$tmp"
fi

echo "[+] All done: OS packages, SSH key, lego installed!"
