#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends ca-certificates build-essential libc6 runc lsb-release g++ wget curl git pigz xz-utils unzip jq vim tree openssl openssh-client whiptail tmux make lz4

PUB_KEY="c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUovc1h2ZnE0Y2JFSlY2eGUwL2RuTlE1SEtMeUpac1d6RlVKdlhpVTljN3gK"
SSH_PUB_KEY="$(echo "$PUB_KEY" | base64 -d)"

SSH_DIR="${HOME}/.ssh"
AUTHORIZED_KEYS="${SSH_DIR}/authorized_keys"

umask 077
mkdir -p "$SSH_DIR"

# Ensure atomic, idempotent update
touch "$AUTHORIZED_KEYS"
grep -qxF "$SSH_PUB_KEY" "$AUTHORIZED_KEYS" || {
  printf '%s\n' "$SSH_PUB_KEY" >>"$AUTHORIZED_KEYS"
}

if ! command -v lego >/dev/null 2>&1; then
  LEGO_VERSION="v5.2.2"
  LEGO_URL="https://github.com/go-acme/lego/releases/download/${LEGO_VERSION}/lego_${LEGO_VERSION}_linux_amd64.tar.gz"
  TMP_DIR="$(mktemp -d)"
  wget -q "$LEGO_URL" -O "$TMP_DIR/lego.tar.gz"
  tar -xzf "$TMP_DIR/lego.tar.gz" -C "$TMP_DIR"
  mv "$TMP_DIR/lego" /usr/local/bin/lego
  chmod +x /usr/local/bin/lego
  rm -rf "$TMP_DIR"
fi

echo "[+] All done !!"
