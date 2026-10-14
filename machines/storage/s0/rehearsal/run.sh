#!/usr/bin/env bash
# Drives the rehearsal in QEMU/KVM on a workstation.
#   run.sh prep <iso-path>      format the virtual disks and install the target
#   run.sh boot                 boot from the disks, wait for the report, power off
#   run.sh hold                 boot and keep running (for a hard kill); prints the pid
#   run.sh boot-a-only          boot with disk B absent (degraded path)
# State lives in $REHEARSAL_DIR (default ./rehearsal-state): disks, LUKS key,
# OVMF variables and one log per run.
set -euo pipefail
cmd=${1:?usage: run.sh prep <iso> | boot | hold | boot-a-only}
DIR=${REHEARSAL_DIR:-./rehearsal-state}; mkdir -p "$DIR"
OVMF=${OVMF:-$(nix build --no-link --print-out-paths nixpkgs#OVMF.fd)}
[ -e "$DIR/vars.fd" ] || cp "$OVMF/FV/OVMF_VARS.fd" "$DIR/vars.fd"; chmod u+w "$DIR/vars.fd"
[ -e "$DIR/key.img" ] || { head -c 32 /dev/urandom > "$DIR/key.img"; truncate -s 1M "$DIR/key.img"; }
[ -e "$DIR/hold.img" ] || truncate -s 1M "$DIR/hold.img"
for d in nvmeA nvmeB; do [ -e "$DIR/$d.qcow2" ] || qemu-img create -q -f qcow2 "$DIR/$d.qcow2" 8G; done
log="$DIR/$cmd-$(date +%Y%m%d-%H%M%S).log"
common=(qemu-system-x86_64 -enable-kvm -machine q35 -cpu host -m 4096 -smp 4 -display none -monitor none
  -serial "file:$log"
  -drive if=pflash,format=raw,readonly=on,file="$OVMF/FV/OVMF_CODE.fd"
  -drive if=pflash,format=raw,file="$DIR/vars.fd"
  -drive file="$DIR/nvmeA.qcow2",if=none,id=da,format=qcow2 -device virtio-blk-pci,drive=da,serial=nvmeA
  -drive file="$DIR/key.img",if=none,id=dk,format=raw -device virtio-blk-pci,drive=dk,serial=luks-key)
diskB=(-drive file="$DIR/nvmeB.qcow2",if=none,id=db,format=qcow2 -device virtio-blk-pci,drive=db,serial=nvmeB)
hold=(-drive file="$DIR/hold.img",if=none,id=dh,format=raw -device virtio-blk-pci,drive=dh,serial=hold)
echo "log: $log"
case $cmd in
  prep)       iso=${2:?iso path}; "${common[@]}" "${diskB[@]}" -cdrom "$iso" -boot d ;;
  boot)       "${common[@]}" "${diskB[@]}" ;;
  hold)       "${common[@]}" "${diskB[@]}" "${hold[@]}" & echo "qemu pid $!"; wait ;;
  boot-a-only) "${common[@]}" ;;
  *) echo "unknown command $cmd" >&2; exit 2 ;;
esac
echo "qemu exited $?"
