#!/usr/bin/env bash
# Phase 4 step 1: copy /data back from the read-only tmppool mount at /data
# into the bcachefs data subvolume mounted at /mnt/newdata. Detached; progress
# in rsync-copyback.log, result in copyback.status.
set -euo pipefail
cd /root/migration
findmnt /data -n -o SOURCE | grep -q '^tmppool/data$' || { echo "/data is not the tmppool copy" >&2; exit 1; }
findmnt /mnt/newdata -n -o FSTYPE | grep -q bcachefs || { echo "/mnt/newdata is not the bcachefs data subvolume" >&2; exit 1; }
echo "start $(date -Is)" > copyback.status
setsid nohup bash -c 'rsync -aHAXS --numeric-ids --info=progress2,stats2 /data/ /mnt/newdata/ > /root/migration/rsync-copyback.log 2>&1; echo "EXIT=$? $(date -Is)" >> /root/migration/copyback.status' >/dev/null 2>&1 < /dev/null &
sleep 3; pgrep -x rsync >/dev/null && echo "copy-back running" || { echo "rsync did not start" >&2; exit 1; }
