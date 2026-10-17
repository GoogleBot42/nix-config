#!/usr/bin/env bash
# Phase 3 step 1a: make sure atticd runs from its SSD copy, unmount
# everything from rpool, export the pool. Reversible: `zpool import -N rpool`
# and the mounts come back. Run after phase3-1-final-send.sh and after the
# atticd copy (atticd-copy.status must say EXIT=0).
set -euo pipefail
grep -q 'EXIT=0' /root/migration/atticd-copy.status || { echo "atticd copy not finished cleanly" >&2; exit 1; }
if mountpoint -q /var/lib/atticd; then
  systemctl stop atticd.service
  systemctl stop var-lib-atticd.mount
  systemctl mask --runtime var-lib-atticd.mount
  systemctl start atticd.service
fi
mountpoint -q /mnt/attic-ssd && umount /mnt/attic-ssd
echo "atticd: $(systemctl is-active atticd.service), $(du -sh /var/lib/atticd | cut -f1) on $(findmnt -n -o FSTYPE -T /var/lib/atticd)"
systemctl stop data.mount 2>/dev/null || true
mountpoint -q /data && umount /data
mountpoint -q /mnt/tmpdata && zfs unmount tmppool/data
zpool export rpool
zpool list -H -o name,health
echo "rpool exported $(date -Is); next: deploy the Phase 3 closure, reboot, unlock two LUKS devices"
