#!/usr/bin/env bash
# Runs inside the rehearsal ISO: builds the two-disk LUKS + bcachefs layout
# with the identifiers target.nix expects and installs the target system.
set -euo pipefail
export PS4='+ $(date +%T) '
set -x
TARGET=$1
A=/dev/disk/by-id/virtio-nvmeA
B=/dev/disk/by-id/virtio-nvmeB
KEYDEV=/dev/disk/by-id/virtio-luks-key
FS=33333333-3333-4333-8333-333333333333
for d in $A $B; do
  sfdisk --quiet --wipe always "$d" <<SF
label: gpt
size=512MiB, type=U, name=ESP
type=CA7D7CCB-63ED-4C53-861C-1742536059CC, name=luks
SF
done
udevadm settle
mkfs.vfat -F 32 -i 0A0A0A0A -n ESP-A "${A}-part1"
mkfs.vfat -F 32 -i 0B0B0B0B -n ESP-B "${B}-part1"
dd if="$KEYDEV" of=/tmp/key bs=32 count=1 status=none
CS="cryptsetup"
$CS luksFormat --type luks2 --batch-mode --uuid 11111111-1111-4111-8111-111111111111 --key-file /tmp/key "${A}-part2"
$CS luksFormat --type luks2 --batch-mode --uuid 22222222-2222-4222-8222-222222222222 --key-file /tmp/key "${B}-part2"
$CS open --key-file /tmp/key "${A}-part2" enc-nvme-a
$CS open --key-file /tmp/key "${B}-part2" enc-nvme-b
bcachefs format --uuid "$FS" --fs_label s0-rehearsal --replicas=2 \
  --foreground_target=ssd --metadata_target=ssd --promote_target=ssd --background_target=ssd \
  --label ssd.nvmea /dev/mapper/enc-nvme-a --label ssd.nvmeb /dev/mapper/enc-nvme-b
mkdir -p /mnt-fs
mount -t bcachefs "UUID=$FS" /mnt-fs
for s in root nix var log home data; do bcachefs subvolume create "/mnt-fs/$s"; done
umount /mnt-fs
mkdir -p /mnt
mount -t bcachefs -o noatime,X-mount.subdir=root "UUID=$FS" /mnt
mkdir -p /mnt/nix /mnt/var /mnt/home /mnt/boot /mnt/boot-mirror
mount -t bcachefs -o noatime,X-mount.subdir=nix "UUID=$FS" /mnt/nix
mount -t bcachefs -o noatime,X-mount.subdir=var "UUID=$FS" /mnt/var
mkdir -p /mnt/var/log
mount -t bcachefs -o noatime,X-mount.subdir=log "UUID=$FS" /mnt/var/log
mount -t bcachefs -o noatime,X-mount.subdir=home "UUID=$FS" /mnt/home
mount "${A}-part1" /mnt/boot
mount "${B}-part1" /mnt/boot-mirror
for m in /mnt /mnt/nix /mnt/var /mnt/var/log /mnt/home /mnt/boot /mnt/boot-mirror; do findmnt -no TARGET,SOURCE,OPTIONS "$m" || echo "NOT MOUNTED: $m"; done
nixos-install --system "$TARGET" --root /mnt --no-root-passwd --no-channel-copy
efibootmgr
ls /mnt/boot/EFI /mnt/boot-mirror/EFI
