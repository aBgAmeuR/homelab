#!/bin/bash
set -euo pipefail

name="${1:?name, e.g. laptop}"
address="${2:?tunnel address, e.g. 10.0.0.3}"
endpoint="${WG_ENDPOINT:?WG_ENDPOINT=<public host or IP>:<port>}"
allowed_ips="${WG_ALLOWED_IPS:-0.0.0.0/0}"
secrets="$(dirname "$0")/../ansible/inventory/group_vars/vpn_servers.sops.yml"

command -v wg >/dev/null || { echo "wg not found: apt install wireguard-tools" >&2; exit 1; }

server_public_key="$(sops -d --extract '["wireguard_private_key"]' "$secrets" | wg pubkey)"
private_key="$(wg genkey)"
public_key="$(printf '%s' "$private_key" | wg pubkey)"

config="[Interface]
PrivateKey = ${private_key}
Address = ${address}/32
DNS = 192.168.1.116

[Peer]
PublicKey = ${server_public_key}
Endpoint = ${endpoint}
AllowedIPs = ${allowed_ips}
PersistentKeepalive = 25"

printf '%s\n\n' "$config"
if command -v qrencode >/dev/null; then
  printf '%s' "$config" | qrencode -t ansiutf8
fi

echo "Add to wireguard_peers in ansible/inventory/group_vars/vpn_servers.yml:"
echo "  - { name: ${name}, address: ${address}, public_key: \"${public_key}\" }"
