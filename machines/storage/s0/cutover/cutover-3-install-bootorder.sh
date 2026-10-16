#!/usr/bin/env bash
# Step 5.5: assemble the target tree with bind mounts, nixos-install the
# pre-copied closure into it, unmount everything, put the NVMe entries first
# in BootOrder. Ends with the reboot command printed, not run.
set -euo pipefail
C=$(cat /root/migration/cutover-closure.txt)
test -e "$C/bin/switch-to-configuration" || { echo "closure $C missing" >&2; exit 1; }
T=/mnt/target
mkdir -p $T
mountpoint -q $T || mount --bind /mnt/s0fs/root $T
for s in nix var home; do mountpoint -q $T/$s || mount --bind /mnt/s0fs/$s $T/$s; done
mountpoint -q $T/var/log || mount --bind /mnt/s0fs/log $T/var/log
mkdir -p $T/boot $T/boot-mirror
mountpoint -q $T/boot || mount /dev/disk/by-uuid/0FFD-389D $T/boot
mountpoint -q $T/boot-mirror || mount /dev/disk/by-uuid/0FFD-7D0B $T/boot-mirror
findmnt -R $T
nixos-install --system "$C" --root $T --no-root-passwd --no-channel-copy
ls -t $T/boot/loader/entries | head -3
diff -rq $T/boot $T/boot-mirror && echo "ESP mirror identical"
umount -R $T
umount /mnt/s0fs
cryptsetup close enc-nvme-a
cryptsetup close enc-nvme-b
EFI=/nix/store/9hblwqv9v3ij6h3w0pj855zhv9rswz0s-efibootmgr-18/bin/efibootmgr
$EFI | grep BootOrder > /root/migration/bootorder-before-cutover.txt
$EFI -o 0005,0006,0001,0000,0002 | grep -E 'BootOrder|Boot000[0-6]'
echo "ready. rollback of this step alone: $EFI -o $(sed 's/BootOrder: //' /root/migration/bootorder-before-cutover.txt)"
echo "to cut over: systemctl reboot   (then unlock six LUKS devices over the remote path)"
