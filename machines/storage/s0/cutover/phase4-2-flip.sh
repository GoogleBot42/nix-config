systemctl unmask --runtime container@transmission.service container@servarr.service 2>/dev/null || true
systemctl reset-failed container@transmission.service container@servarr.service 2>/dev/null || true
#!/usr/bin/env bash
# Phase 4 step 3: after the copy-back finished with EXIT=0, swap /data from
# the tmppool copy to the bcachefs data subvolume and start the writers.
set -euo pipefail
cd /root/migration
grep -q 'EXIT=0' copyback.status || { echo "copy-back not finished cleanly" >&2; exit 1; }
systemctl stop samba-smbd samba-nmbd samba-winbindd samba-wsdd jellyfin
zfs unmount tmppool/data
zfs set mountpoint=/mnt/tmpdata tmppool/data
# the bulk load wrote straight to the HDDs; new /data writes go back to
# landing on the SSD tier and migrating in the background
bcachefs set-file-option --foreground_target=- /mnt/newdata
getfattr --absolute-names -d -m - /mnt/newdata 2>/dev/null | grep bcachefs_effective || true
umount /mnt/newdata
systemctl start data.mount
findmnt /data -n -o SOURCE,FSTYPE
ls /data/samba
systemctl reset-failed container@transmission.service container@servarr.service 2>/dev/null || true
systemctl start samba-smbd samba-nmbd samba-winbindd samba-wsdd jellyfin container@pia-vpn container@transmission container@servarr
sleep 5
systemctl is-active samba-smbd jellyfin container@transmission container@servarr | tr '\n' ' '; echo
echo "flipped $(date -Is); next: bcachefs scrub /"
