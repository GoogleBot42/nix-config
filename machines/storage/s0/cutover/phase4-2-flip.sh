#!/usr/bin/env bash
# Phase 4 step 3: after the copy-back finished with EXIT=0, swap /data from
# the tmppool copy to the bcachefs data subvolume and start the writers.
set -euo pipefail
cd /root/migration
grep -q 'EXIT=0' copyback.status || { echo "copy-back not finished cleanly" >&2; exit 1; }
systemctl stop samba-smbd samba-nmbd samba-winbindd samba-wsdd jellyfin
zfs unmount tmppool/data
zfs set mountpoint=/mnt/tmpdata tmppool/data
umount /mnt/newdata
systemctl start data.mount
findmnt /data -n -o SOURCE,FSTYPE
ls /data/samba
systemctl reset-failed container@transmission.service container@servarr.service 2>/dev/null || true
systemctl start samba-smbd samba-nmbd samba-winbindd samba-wsdd jellyfin container@pia-vpn container@transmission container@servarr
sleep 5
systemctl is-active samba-smbd jellyfin container@transmission container@servarr | tr '\n' ' '; echo
echo "flipped $(date -Is); next: bcachefs scrub /"
