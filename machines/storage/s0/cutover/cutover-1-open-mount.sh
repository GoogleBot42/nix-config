#!/usr/bin/env bash
# Step 5.3: open the NVMe LUKS members with the throwaway key and mount the
# whole bcachefs tree at /mnt/s0fs (subvolumes root nix var log home data).
# Safe to re-run. Changes nothing on rpool.
set -euo pipefail
K=/root/s0-migration-luks.key
UUID=3460f75d-5c8c-4511-a6dc-3a69659776f3
open() { cryptsetup status "$1" >/dev/null 2>&1 || cryptsetup open --key-file "$K" "/dev/disk/by-uuid/$2" "$1"; }
open enc-nvme-a 3b8e47ca-a6b9-49e0-94ea-62a9493e8d18
open enc-nvme-b f3fc4503-7035-441c-80fc-c8287b39e92f
mkdir -p /mnt/s0fs
if ! mountpoint -q /mnt/s0fs; then
  mount -t bcachefs -o noatime "UUID=$UUID" /mnt/s0fs \
    || mount -t bcachefs -o noatime /dev/mapper/enc-nvme-a:/dev/mapper/enc-nvme-b /mnt/s0fs
fi
for d in root nix var log home; do test -d /mnt/s0fs/$d || { echo "missing subvolume $d" >&2; exit 1; }; done
findmnt /mnt/s0fs
bcachefs fs usage -h /mnt/s0fs | head -12
