#!/usr/bin/env bash
# Second copy of the pre-cutover OS datasets (snapshot @os3) onto the
# stepping-stone pool, next to /data. atticd store left out: reproducible,
# and its copy on the SSD tier is the live one. Received without
# mountpoints so nothing from it can ever mount into the live tree.
set -o pipefail
cd /root/migration
echo "start $(date -Is)" > zfs-send-os.status
job() { echo "== $1 $(date -Is)" >> zfs-send-os.status; shift; "$@" >> zfs-send-os.log 2>&1; echo "EXIT=$? $(date -Is)" >> zfs-send-os.status; }
job home    bash -c "zfs send -c -R rpool/nixos/home@os3 | zfs recv -u -x mountpoint tmppool/os/home"
job var     bash -c "zfs send -c rpool/nixos/var@os3 | zfs recv -u -x mountpoint -o canmount=off tmppool/os/var"
job var/lib bash -c "zfs send -c rpool/nixos/var/lib@os3 | zfs recv -u -x mountpoint tmppool/os/var/lib"
job var/log bash -c "zfs send -c rpool/nixos/var/log@os3 | zfs recv -u -x mountpoint tmppool/os/var/log"
job root    bash -c "zfs send -c -R rpool/nixos/root@os3 | zfs recv -u -x mountpoint tmppool/os/root"
echo "done $(date -Is)" >> zfs-send-os.status
