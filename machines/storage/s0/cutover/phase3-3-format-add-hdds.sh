#!/usr/bin/env bash
# Phase 3 steps 2-4. POINT OF NO RETURN: wipes the three remaining HDDs (the
# old rpool members), LUKS-formats each with the throwaway key, adds them to
# the bcachefs filesystem under label hdd.*, and points the data subvolume's
# background target at the hdd tier with erasure coding. Refuses to run if
# rpool is importable, if tmppool lacks the verified copies, or if a target
# is not an old rpool member.
set -euo pipefail
K=/root/s0-migration-luks.key
FS=3460f75d-5c8c-4511-a6dc-3a69659776f3
declare -A DRIVES=( [hdd1]=2BJJ97DN [hdd2]=2PGSVB9T [hdd3]=2BJ9K30N )
cd /root/migration
zpool list -H -o name 2>/dev/null | grep -qx rpool && { echo "rpool is imported, refusing" >&2; exit 1; }
zfs list -H -o name tmppool/data@mig4 tmppool/os/home@os3 tmppool/os/root@os3 tmppool/os/var/lib@os3 tmppool/os/var/log@os3 >/dev/null
zpool status -x tmppool | grep -q "is healthy" || { echo "tmppool not healthy" >&2; exit 1; }
pkill -x dd || true; sleep 2
echo "format start $(date -Is)" >> hdd-format.status
for n in hdd1 hdd2 hdd3; do
  s=${DRIVES[$n]}; id=/dev/disk/by-id/ata-WDC_WD160EDGZ-11B2DA0_$s
  test -e "$id"
  dev=$(readlink -f "$id")
  blkid -s UUID -o value "${dev}1" | grep -qE '^(5d1002b8|f7275585|e2c7402a)' || { echo "$s is not an old rpool member, refusing" >&2; exit 1; }
  cryptsetup status "enc-$n" >/dev/null 2>&1 && { echo "enc-$n already open" >&2; exit 1; }
  echo "== $n $s $dev $(date -Is)"
  # whole-disk LUKS, no partition table: the old LUKS header on partition 1
  # is wiped first so no stale signature survives inside the new container
  wipefs -a "${dev}1" >/dev/null
  wipefs -a "$dev" >/dev/null
  udevadm settle
  part="$id"
  cryptsetup luksFormat --type luks2 --batch-mode --key-file "$K" "$part"
  cryptsetup open --key-file "$K" "$part" "enc-$n"
  dm=$(basename "$(readlink -f /dev/mapper/enc-$n)")
  rot=$(cat /sys/block/$dm/queue/rotational)
  [ "$rot" = 1 ] || { echo "enc-$n reports rotational=$rot, stop and look" >&2; exit 1; }
  uuid=$(blkid -s UUID -o value "$part")
  echo "enc-$n $uuid $s" | tee -a hdd-luks-uuids.txt
done
for n in hdd1 hdd2 hdd3; do
  bcachefs device add --label "hdd.$n" / "/dev/mapper/enc-$n"
done
bcachefs fs usage -h / | grep -E '^(ssd|hdd)\.'
mkdir -p /mnt/newdata
mountpoint -q /mnt/newdata || mount -t bcachefs -o noatime,X-mount.subdir=data "UUID=$FS" /mnt/newdata
bcachefs set-file-option --background_target=hdd --erasure_code=1 /mnt/newdata \
  || bcachefs set-file-option --background_target=hdd --erasure_code /mnt/newdata
echo "format done $(date -Is)" >> hdd-format.status
echo "next: copy back with phase4-1-copyback.sh"
