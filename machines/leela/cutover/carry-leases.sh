#!/usr/bin/env bash
# Copy the OpenWrt gateway's live DHCP lease table to leela and leave dnsmasq
# stopped there, so the next boot (the one that goes live) starts with every
# current lease already known. Run this as the last step before powering
# leela off for the swap.
#
# usage: carry-leases.sh <leela address>
set -euo pipefail

leela=${1:?usage: carry-leases.sh <leela address>}
openwrt=root@192.168.1.1

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

ssh "$openwrt" cat /tmp/dhcp.leases > "$tmp"
echo "$(wc -l < "$tmp") leases fetched from the router"

ssh "root@$leela" 'systemctl stop dnsmasq && install -o dnsmasq -m 644 /dev/stdin /var/lib/dnsmasq/dnsmasq.leases' < "$tmp"
echo "installed on leela; dnsmasq left stopped until the next boot"
