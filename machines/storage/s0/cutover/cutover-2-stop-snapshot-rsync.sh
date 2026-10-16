#!/usr/bin/env bash
# Step 5.4: stop every /var/lib writer, snapshot rpool/nixos@os3, rsync the
# OS from the snapshots into the NVMe tree with --delete.
#   --dry-run   keep services running, snapshot @os3dry, rsync -n, destroy it
# Requires cutover-1-open-mount.sh to have run. Logs in /root/migration/.
set -euo pipefail
cd /root/migration
mountpoint -q /mnt/s0fs || { echo "/mnt/s0fs not mounted" >&2; exit 1; }
WRITERS=(
  container@gitea-runner container@pia-vpn container@servarr container@transmission
  gitea-runner-podman gitea-runner-ubuntu
  home-assistant unifi frigate jellyfin atticd postgresql actual vikunja esphome
  mosquitto zigbee2mqtt redis-outline wyoming-faster-whisper-hass wyoming-piper-hass
  samba-smbd samba-nmbd samba-winbindd samba-wsdd
)
TIMERS=(restic-backups-samba restic-backups-vikunja restic-backups-actual-budget)
if [ "${1:-}" = --dry-run ]; then
  SNAP=os3dry; DRY=-n; TAG=dry
else
  SNAP=os3; DRY=; TAG=cutover
  echo "stopping writers $(date -Is)"
  systemctl stop "${TIMERS[@]/%/.timer}"
  systemctl stop "${WRITERS[@]/%/.service}"
  systemctl list-units --type=service --state=running --no-legend | awk '{print $1}' > running-after-stop.txt
  echo "still running: $(wc -l < running-after-stop.txt) services (see running-after-stop.txt)"
fi
zfs list -t snapshot -H -o name "rpool/nixos@$SNAP" >/dev/null 2>&1 && zfs destroy -r "rpool/nixos@$SNAP"
zfs snapshot -r "rpool/nixos@$SNAP"
R="rsync -aHAXS --numeric-ids --delete $DRY --info=stats2"
job() { local name=$1; shift; echo "== $name $(date -Is)"; "$@" > "rsync-$TAG-$name.log" 2>&1 || { echo "$name FAILED exit=$?"; exit 1; }; grep -E 'Number of (regular files transferred|deleted files)|Total transferred' "rsync-$TAG-$name.log"; }
job root   $R --exclude=/nix/* --exclude=/var/* --exclude=/tmp/* --exclude=/mnt/* --exclude=/home/* --exclude=/data/* --exclude=/boot/* --exclude=/boot-mirror/* "/.zfs/snapshot/$SNAP/" /mnt/s0fs/root/
job var    $R --exclude=/lib/* --exclude=/log/* "/.zfs/snapshot/$SNAP/var/" /mnt/s0fs/var/
job nix    $R "/.zfs/snapshot/$SNAP/nix/" /mnt/s0fs/nix/
job log    $R "/var/log/.zfs/snapshot/$SNAP/" /mnt/s0fs/log/
job home   $R "/home/.zfs/snapshot/$SNAP/" /mnt/s0fs/home/
job varlib $R --exclude=/atticd/* "/var/lib/.zfs/snapshot/$SNAP/" /mnt/s0fs/var/lib/
if [ -z "$DRY" ]; then
  mkdir -p /mnt/s0fs/root/{boot,boot-mirror,nix,var,home,data,tmp,mnt} /mnt/s0fs/var/{lib,log} /mnt/s0fs/var/lib/atticd
  echo "rsync done $(date -Is); next: cutover-3-install-bootorder.sh"
else
  zfs destroy -r "rpool/nixos@$SNAP"
  echo "dry run done; nothing changed"
fi
