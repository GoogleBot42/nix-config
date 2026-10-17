#!/usr/bin/env bash
# Phase 3 pre-flight: stop every /data writer, snapshot rpool/nixos/data@mig4,
# send the increment since @mig3 to tmppool/data, verify the guids match and
# nothing is left unsent. The writers stay stopped: /data goes away next.
set -euo pipefail
cd /root/migration
WRITERS=(samba-smbd samba-nmbd samba-winbindd samba-wsdd jellyfin container@transmission container@servarr container@pia-vpn)
echo "stopping /data writers $(date -Is)"
systemctl stop "${WRITERS[@]/%/.service}"
for p in /proc/[0-9]*; do (ls -l $p/fd $p/cwd 2>/dev/null | grep -q " /data") && echo "still has /data open: $(cat $p/comm) (pid ${p#/proc/})"; done; true
zfs list -t snapshot -H -o name rpool/nixos/data@mig4 >/dev/null 2>&1 && { echo "mig4 already exists" >&2; exit 1; }
zfs snapshot rpool/nixos/data@mig4
zfs send -c -I @mig3 rpool/nixos/data@mig4 | zfs recv tmppool/data
echo "--- guids"
zfs list -t snapshot -H -o name,guid rpool/nixos/data@mig4 tmppool/data@mig4
a=$(zfs get -H -o value guid rpool/nixos/data@mig4); b=$(zfs get -H -o value guid tmppool/data@mig4)
[ "$a" = "$b" ] || { echo "GUID MISMATCH" >&2; exit 1; }
echo "--- unsent (must be empty)"
zfs diff rpool/nixos/data@mig4 rpool/nixos/data 2>/dev/null | head
echo "final send done $(date -Is); tmppool/data is at mig4"
