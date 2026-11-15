#!/usr/bin/env bash
# Install the OpenWrt gateway's SSH host key on leela so the key in
# properties.nix (and every machine's known_hosts) stays valid after the swap.
#
# usage: carry-host-key.sh <leela address>
# Needs ssh as root to both the OpenWrt router (192.168.1.1) and leela.
set -euo pipefail

leela=${1:?usage: carry-host-key.sh <leela address>}
openwrt=root@192.168.1.1
here=$(dirname "$(readlink -f "$0")")

tmp=$(mktemp -d)
chmod 700 "$tmp"
trap 'rm -rf "$tmp"' EXIT

ssh "$openwrt" cat /etc/dropbear/dropbear_ed25519_host_key > "$tmp/dropbear"
nix shell nixpkgs#dropbear -c dropbearconvert dropbear openssh "$tmp/dropbear" "$tmp/key" >/dev/null
ssh-keygen -y -f "$tmp/key" > "$tmp/key.pub"

expected=$(grep -o 'ssh-ed25519 [A-Za-z0-9+/=]*' "$here/../properties.nix")
actual=$(cut -d' ' -f1,2 "$tmp/key.pub")
if [ "$actual" != "$expected" ]; then
  echo "converted key does not match properties.nix hostKey:" >&2
  echo "  properties.nix: $expected" >&2
  echo "  router:         $actual" >&2
  exit 1
fi

ssh "root@$leela" 'install -m 600 /dev/stdin /etc/ssh/ssh_host_ed25519_key' < "$tmp/key"
ssh "root@$leela" 'ssh-keygen -y -f /etc/ssh/ssh_host_ed25519_key > /etc/ssh/ssh_host_ed25519_key.pub && systemctl restart sshd'
echo "leela now presents $(ssh-keygen -lf "$tmp/key.pub")"
