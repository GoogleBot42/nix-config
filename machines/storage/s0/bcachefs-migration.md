# s0: migrate from ZFS raidz1 to one bcachefs filesystem

Runbook for an agent session executing the migration. It assumes no context
from the planning session; everything it relies on is written down here.
Update the **Progress log** at the bottom as phases complete, and keep this
file in the repo (commit it with the config changes of each phase).

## Goal

s0 is the always-on home server. Today the whole OS and all data live on a
ZFS raidz1 of four 16 TB WD HDDs behind LUKS, so the disks never spin down and
burn roughly 20 to 28 W around the clock. Two 2 TB NVMe drives sit unused.

End state:

- One bcachefs filesystem spanning two NVMe drives and **three** of the four
  HDDs (the owner wants to right-size; the fourth drive stays out as a spare).
- Root, Nix store, /var, /home and every service's hot state pinned to the
  NVMe tier so the HDDs only wake for cold data in /data.
- /data on the HDDs with erasure coding, 2+1 stripes, about 29 TB usable
  against 19 TB used.
- LUKS underneath every member device, as today. Not bcachefs native
  encryption (see gotchas).
- /boot on the NVMe drives, not on the USB stick it is on today.
- HDDs spin down when idle, verified by measurement.

The owner chose bcachefs knowingly after a review of its recent bug history.
Do not re-litigate the choice; do apply the conditions in "Decisions".

## Working as root on s0

A temporary key was deployed for this migration:

```
ssh -i ~/.ssh/s0-migration root@s0
```

The private key lives on fry at `~/.ssh/s0-migration`. `root@s0` resolves over
the tailnet. Remove the key from `machines/storage/s0/default.nix` and delete
it from fry when the migration is done.

The owner must type the LUKS passphrase at every `cryptsetup luksFormat` and
`luksOpen` of a new device. Stage those commands and hand them over; do not
guess at passphrases or try to read them from anywhere.

## Inventory (as of 2026-10-10)

Motherboard ASUS ProArt B650-CREATOR, Ryzen 9 7900X, 124 GB ECC RAM, kernel
6.18 LTS from nixpkgs (CONFIG_RUST=y).

| Device | Identity | Today | Fate |
|---|---|---|---|
| nvme1n1 | SOLIDIGM SSDPFKKW020X7 serial SSC6N475610206L4S, 1.9 TB | empty, unpartitioned | ESP + LUKS + bcachefs (SSD tier) |
| nvme2n1 | SOLIDIGM SSDPFKKW020X7 serial SSC6N475610206L4Z, 1.9 TB | empty, unpartitioned | ESP mirror + LUKS + bcachefs (SSD tier) |
| nvme0n1 | Samsung 970 EVO 1 TB serial S467NX0M808190F | old install, two closed LUKS containers | **Do not touch.** Owner has other plans for it. |
| sda | WDC WD160EDGZ serial 2BJJ97DN | LUKS `enc-pv3`, rpool member | one of the three HDD members, or the spare |
| sdb | WDC WD160EDGZ serial 3JH0HT6G | LUKS `enc-pv1`, rpool member | same |
| sdc | WDC WD160EDGZ serial 2BJ9K30N | LUKS `enc-pv4`, rpool member | same |
| sdd | WDC WD160EDGZ serial 2PGSVB9T | LUKS `enc-pv2`, rpool member | same |
| sdg | Kingston DataTraveler 14 GB | `/boot` (vfat UUID 4FB4-738E) + unused ext4 | retired after Phase 1 |
| sde | PNY 115 GB USB stick, vfat | unknown contents | ask the owner; leave alone |
| sdf | "Linux File-Stor Gadget", 0 B | some USB gadget | ignore |

Stepping stones the owner will attach: one external 16 TB USB HDD and two
4 TB HDDs, **all three over USB-to-SATA adapters**. The board's own SATA
connectors are full, and the owner's 4-port PCIe SATA card must stay out of
the machine: with anything attached to it the board does not POST. Identify
every stepping stone by `/dev/disk/by-id` serial before touching it. Letters
move between boots, and USB devices re-enumerate on every replug.

Which HDD becomes the spare does not matter technically. Pick the one with
the worst SMART history (`smartctl -a`), confirm with the owner.

### Current layout

```
rpool (raidz1-0 of enc-pv1..4)        19.0 TB used, 23 TB avail, atime=on
  rpool/nixos/root       /            66.5 GB   (includes /nix/store)
  rpool/nixos/var/lib    /var/lib      1.42 TB  (of which atticd 324 GB)
  rpool/nixos/var/log    /var/log      2.3 GB
  rpool/nixos/home       /home        132 GB
  rpool/nixos/data       /data        17.4 TB
/boot                    sdg1 vfat
```

/data holds `samba/Public/{Documents,Media,Pictures,Videos,Plex,Stuff,
"Picture Frame","No Backup"}` and `nix-binary-cache`. Media is served by
Jellyfin and written by Transmission into `/data/samba/Public/Media/
Transmission`; Transmission's incomplete directory is
`/var/lib/transmission/.incomplete`. Frigate keeps 7 to 10 days of camera
recordings under `/var/lib/frigate`. Four systemd-nspawn containers
(gitea-runner, pia-vpn, servarr, transmission) and podman state live under
/var/lib. Home Assistant, UniFi (Mongo), Nextcloud-adjacent services and the
attic binary cache are also under /var/lib.

Restic backups (`common/backups.nix`) run nightly for groups `samba`,
`vikunja` and `actual-budget`. The module takes ZFS snapshots to back up from;
it has no bcachefs snapshot support yet and will fall back to backing up the
live tree. That is acceptable during the migration and a follow-up after.

Remote LUKS unlock (`common/boot/remote-luks-unlock.nix`) runs sshd and a Tor
hidden service in the initrd over VLAN netdevs on eno1. The zfs-specific part
(holding `zfs-import-rpool` until cryptsetup finishes) becomes irrelevant once
root is bcachefs; the LUKS and network parts stay.

## Decisions already made, and why

1. **One filesystem, OS included.** Owner's explicit wish. It is what
   bcachefs tiering is for, and per-directory IO options let the OS live on
   flash while /data lives on the HDDs in the same namespace.
2. **LUKS under every member, no native encryption.** Issue
   koverstreet/bcachefs-tools#1056 (open since 2026-04): on encrypted
   filesystems with SSD foreground/promote targets and HDD background target
   plus erasure coding, data moved to the HDDs is reported corrupt by scrub
   and by reads until a reboot. That is exactly this topology. LUKS also keeps
   the existing remote-unlock flow.
3. **Erasure coding only on /data, replicas=2 everywhere.** The filesystem
   default is two replicas, which on the SSD pair is a mirror. `erasure_code`
   is set on the /data subvolume only, so with three HDDs in the background
   target the data forms 2+1 stripes. Setting erasure coding filesystem-wide
   would also stripe the SSD mirror, which is pointless.
4. **Metadata on the SSDs only.** `metadata_target=ssd` keeps directory walks
   and library scans off the HDDs. Consequence: the two Solidigms are now the
   filesystem; lose both and everything is gone, same as a ZFS special vdev.
   A third metadata copy on the HDDs would wake them on every metadata write.
   Owner accepted this.
5. **Version pin.** `overlays/bcachefs-tools.nix` pins bcachefs-tools and the
   kernel module to a 2026-10-06 master snapshot after v1.39.7, because the
   tag lacks three erasure-coding fixes that landed two days later (#1088
   RAID6 two-block recovery, #1092 crash-resumed stripe update re-keying
   extents into the wrong block, #1090 reconstruct racing a stripe deletion).
   Do not bump nixpkgs for this; do not move the pin into the Rust-conversion
   churn that starts the evening of October 6 without rebuilding and
   re-testing. When a tagged release containing those fixes exists, prefer it.
6. **Copy-based migration, never `bcachefs device evacuate`/`remove`.**
   September's stress campaign (#913 and friends) found evacuate and remove
   hanging or failing about half the time on EC arrays. We only ever format
   fresh devices, `device add`, and copy in.
7. **The temporary copy is ZFS, not bcachefs.** Stepping stones form a
   throwaway striped zpool; /data moves there with `zfs send | zfs recv`,
   which is checksummed, snapshot-consistent, resumable and incremental.
   bcachefs then receives one copy of static data from a quiet source. The
   temporary pool is kept on a shelf afterwards as the escape hatch.
8. **OS first, HDDs last.** Root moves to the NVMe filesystem while rpool is
   untouched, and runs there for days before anything destructive happens.
9. **Spare drive stays out.** Three HDDs in the final pool. Capacity can grow
   later with `device add`, which is the safe direction.

## Gotchas collected from the bug tracker and the code

- **Degraded boot.** With root on a filesystem that spans the HDDs, a dead or
  slow HDD blocks the root mount unless the mount is allowed to proceed
  degraded. 1.39.3 added `degraded=ask` with `missing_dev_timeout`; an
  initrd that asks questions over a Tor ssh session is a trap. Decide the
  mount option (`degraded` for the root mount is the likely answer, since
  the OS subvolumes have both copies on the SSDs) and **test it by pulling an
  HDD's power in Phase 4** before declaring victory.
- **Writes to a degraded EC array can hang** on stripe buffer memory
  (#1057, open). Keep an eye on `stripe_buf_mem_blocked` in
  `/sys/fs/bcachefs/<uuid>/` if a disk ever drops out.
- **Reconcile idles on an IO clock that only advances with write
  throughput** (#920). Background moves may sit until something writes. This
  also means reconcile will run whenever /data is written, waking the HDDs;
  if spin-down matters, look for a way to batch it (the option name has
  changed across versions; check `bcachefs set-fs-option --help` on the
  installed tools). Measure rather than assume.
- **Rotational detection is sticky.** A device's `rotational` flag is read
  when it is added and there is no supported way to change it later (1.39.3
  changelog). dm-crypt passes the flag through, but check
  `/sys/block/dm-N/queue/rotational` for each LUKS mapping before `device
  add`: HDDs must read 1, NVMe 0. Since 1.39.7 `set-fs-option --rotational=`
  persists an explicit choice.
- **Recurring stalls with EC after upgrades** were reported through 1.39.6
  (#1083). After every bcachefs version bump, watch `dmesg` for
  `btree trans held srcu lock` warnings and check `bcachefs fs top`.
- **Subcommand names changed between releases** (set-option, set-fs-option,
  set-file-option, setattr). Verify every command against `bcachefs --help`
  of the installed build before running it; the commands below are
  intentions, not verified invocations.
- **Mount by UUID.** The NixOS module handles `device = "UUID=<external
  uuid>"` and expects the mount helper to find all member devices. Device
  paths containing colons are not supported in `fileSystems.<name>.device`
  because the module splits on `:`.
- **Rust in the module.** Post-1.39.7 master makes Rust a hard dependency of
  the kernel module. nixpkgs builds the module with the kernel's own Rust
  toolchain and `RUST_LIB_SRC`, and this is what the overlay was build-tested
  against. Any nixpkgs or kernel bump must rebuild
  `nixosConfigurations.s0.config.boot.kernelPackages.callPackage pkgs.bcachefs-tools.kernelModule {}`
  before deploy.
- **Hard resets.** s0 has a history of unexplained resets. Unclean shutdowns
  are where young filesystems get hurt (#1203 lost a journal entry with
  `metadata_replicas=1`). Keep `metadata_replicas=2`, and keep the restic
  backups and the shelf copy.
- **USB stepping stones.** All three temporary drives are on USB-to-SATA
  adapters, so the temporary pool's weakest link is USB. Spread the three
  adapters across different controllers (the chipset USB 3.2 controller at
  09:00.0 and the two CPU xHCI controllers at 0c:00.3 and 0c:00.4; `lsusb -t`
  shows the tree), never behind one hub, each adapter on its own power
  supply. UAS resets under sustained load are common on consumer adapters;
  if `dmesg` shows them, pin the adapter to BOT with `usb-storage.quirks=
  <vid>:<pid>:u` on the kernel command line. A USB drop suspends the pool:
  set `zpool set failmode=continue tmppool`, use `zfs recv -s` so an
  interrupted send resumes from its token (`zfs get receive_resume_token`),
  and expect 19 TB to take well over a day at USB speeds. Run every long
  transfer in `tmux` on s0, never in an ssh session's foreground. Scrub the
  temporary pool after the copy precisely because the transport is flaky.
- **Do not add the PCIe SATA card** to get more ports; the board does not
  boot with it populated.
- **rsync flags.** OS copies need `-aHAXS --numeric-ids` (hardlinks matter
  in /nix/store; ACLs and xattrs matter for capabilities and SELinux-free
  setuid bits). Copy from ZFS snapshots (`/.zfs/snapshot/<name>/`), not from
  the live tree, so a database is never caught mid-write.
- **nspawn containers and podman** keep state under /var/lib; their units
  must be stopped for the final OS sync. `machinectl list` and `podman ps`
  show what is running.
- **atime.** rpool has atime on. Mount the new filesystem `noatime`, or
  every media read will dirty metadata.
- **Backups during the migration.** The restic timers fire nightly around
  00:40. They will keep working from the live tree. Do not let a backup run
  overlap the final cutover rsync.
- **ZFS stays installed.** Keep `boot.supportedFilesystems` containing `zfs`
  and `networking.hostId` so the temporary pool and the shelf copy remain
  importable. `services.zfs.autoScrub` and `services.zfs.trim` can go once
  rpool is destroyed.

## Phase 0: preparation and rehearsal

Prerequisites the owner handles: this branch merged and deployed to s0
(root key, overlay, `boot.supportedFilesystems = [ "zfs" "bcachefs" ]`),
stepping stones attached and powered, a free evening for the Phase 1 reboot.

1. On s0 as root: `modprobe bcachefs && bcachefs version && dmesg | tail`.
   The version must be the pinned snapshot. Record it in the progress log.
2. Confirm restic backups are green and recent: `systemctl list-timers
   'restic*'`, and `restic_samba snapshots` (the `restic_<group>` wrappers come
   from `common/backups.nix`). Ask the owner which parts of /data are
   irreplaceable; "No Backup" is presumably not.
3. Practice on loop devices, on s0, as root: create three 2 GB sparse files
   plus two 1 GB files, format a bcachefs with the exact labels, targets and
   replica settings planned below, create subvolumes, set per-subvolume
   options, write data, confirm with `bcachefs fs usage` that OS-subvolume
   data lands only on the "ssd" label and /data forms stripes. Record the
   verified command lines in this file; they replace the intentions below.
4. **Rehearse the boot path in a VM.** The repo has VM tooling
   (`common/sandboxed-workspace`, backend `vm`) and NixOS has
   `nixos-rebuild build-vm`. Build a VM with two virtual disks carrying ESP
   + LUKS + bcachefs root, `remoteLuksUnlock` disabled, and prove it boots,
   then prove it boots with one member missing using the chosen degraded
   option. Do not skip this; the initrd is where a wrong assumption costs a
   drive to the colo-style debugging the owner has already suffered.
5. Check the two 4 TB and the 16 TB USB drives with `smartctl -a` and a short
   self-test. They are about to hold the only second copy.

## Phase 1: the OS moves to the NVMe tier

Nothing in this phase touches rpool or the HDDs. Rollback is "boot the USB
stick again".

1. Partition both Solidigms identically (`sgdisk`): partition 1 is a 1 GiB
   ESP (type ef00), partition 2 is the rest (type 8309). Record PARTUUIDs.
2. `cryptsetup luksFormat --type luks2` on both partition 2s (owner types the
   passphrase, same passphrase as the existing drives so the initrd prompt
   stays one question), then `luksOpen` as `enc-nvme1` and `enc-nvme2`.
   Record the LUKS UUIDs.
3. Format (verify syntax on the installed tools first):

   ```
   bcachefs format \
     --fs_label s0 \
     --replicas=2 \
     --foreground_target=ssd --metadata_target=ssd --promote_target=ssd \
     --background_target=ssd \
     --label ssd.nvme1 /dev/mapper/enc-nvme1 \
     --label ssd.nvme2 /dev/mapper/enc-nvme2
   ```

   `background_target=ssd` is deliberate: until the HDDs exist, and for every
   subvolume that is not /data forever, data stays on flash. Record the
   external UUID (`bcachefs show-super`).
4. Mount at /mnt and create subvolumes: `root`, `nix`, `var`, `var/log`,
   `home`, `data`. Mount `noatime`. Set no special options on the OS
   subvolumes; they inherit the SSD targets.
5. Snapshot rpool and copy the OS from the snapshots with
   `rsync -aHAXS --numeric-ids`: `rpool/nixos/root@os1` to `root` and `nix`
   (the store is inside the root dataset today), `rpool/nixos/var/lib@os1`
   and `var/log@os1` under `var`, `rpool/nixos/home@os1` to `home`. Expect
   about 1.6 TB; atticd's 324 GB cache is reproducible and may be excluded if
   space is tight (1.9 TB mirror, so it is not tight yet).
6. Write the NixOS config on a branch (worktree, per CLAUDE.md):
   - `boot.initrd.luks.devices.enc-nvme1/2` by LUKS UUID; keep the four HDD
     entries for now (rpool still mounts at /data).
   - `fileSystems."/"`, `"/nix"`, `"/var"`, `"/var/log"`, `"/home"` as
     `fsType = "bcachefs"`, `device = "UUID=<external uuid>"`, options
     `subvol=<name>` and `noatime`. Check how the module wants the
     subvolume option spelled.
   - `fileSystems."/data"` stays `rpool/nixos/data` on zfs for now.
   - `boot.initrd.supportedFilesystems.bcachefs = true`.
   - `/boot` on nvme1's ESP by its new UUID, with
     `boot.loader.systemd-boot.extraInstallCommands` mirroring the ESP to
     nvme2's ESP (plain `rsync -a --delete` of the mounted second ESP), so
     either NVMe boots the box.
   - Keep `remoteLuksUnlock.enable = true`; drop nothing else yet.
7. Install the bootloader into the new ESP from the running system with
   `nixos-enter --root /mnt` (bind-mount the ESP at /mnt/boot first) and
   `nixos-install --root /mnt --no-root-passwd --flake` or `nixos-enter` +
   `switch-to-configuration boot`, whichever the rehearsal proved. Build the
   system closure on s0 itself; the host has the RAM.
8. Stop every service that writes under /var/lib (`systemctl isolate
   rescue.target` is the blunt tool; stopping the nspawn `container@*`,
   podman, hass, unifi, frigate, nextcloud-class services individually is
   gentler), snapshot `@os2`, rsync incrementally from `@os2` snapshots,
   then reboot with the owner present and the BIOS boot order set to nvme1.
9. Verify: `findmnt`, every service healthy, Gatus green, remote unlock
   works on a second reboot, `bcachefs fs usage` shows all data on `ssd`.
10. **Run on this for several days before Phase 3.** Record the date.

## Phase 2: /data to the temporary pool

Non-destructive. Can overlap with the Phase 1 soak.

1. Build the stripe: `zpool create -o ashift=12 -O compression=lz4
   -O atime=off -O mountpoint=none tmppool <by-id of 16T USB> <by-id of 4T>
   <by-id of 4T>`. 24 TB raw, no redundancy, by design.
2. `zfs snapshot rpool/nixos/data@mig1`, then in tmux:
   `zfs send -R -c rpool/nixos/data@mig1 | pv | zfs recv -F tmppool/data`.
   Days, not hours, over USB.
3. `zpool scrub tmppool`; must finish clean. Compare `zfs list -o used` on
   both sides and spot-check sha256 of a few hundred random files.

## Phase 3: point of no return

Everything before this line is reversible. **Stop and get the owner's explicit
go-ahead in writing before step 3.** Pre-flight:

- Phase 1 soak complete with no filesystem errors in `dmesg`.
- tmppool scrub clean, spot checks pass.
- restic backups green within the last 24 h.
- Final incremental: stop Samba, Jellyfin, the servarr and transmission
  containers and anything else that writes /data; `zfs snapshot
  rpool/nixos/data@mig2`; `zfs send -R -c -I @mig1 rpool/nixos/data@mig2 |
  zfs recv tmppool/data`. Verify again.

Then:

1. `umount /data`, `zpool export rpool`. Remove the four `enc-pv*` entries
   and the `/data` zfs mount from the NixOS config, deploy, reboot to prove
   the box comes up without rpool. (This is also the moment the USB boot
   stick is no longer needed.)
2. Choose the spare; label it physically. On the other three:
   `cryptsetup luksFormat --type luks2` (owner types), open as `enc-hdd1..3`,
   check `/sys/block/dm-N/queue/rotational` reads 1.
3. `bcachefs device add --label hdd.hdd1 /dev/mapper/enc-hdd1` and so on.
   `bcachefs fs usage` must show three new members in label group `hdd`.
4. On the data subvolume set `background_target=hdd`, `erasure_code` on,
   `data_replicas=2` (inherited default). Everything else keeps the
   filesystem defaults, so the OS never migrates to the HDDs.
5. Add the three new LUKS UUIDs to `boot.initrd.luks.devices`, deploy, reboot
   once more so the initrd path with five LUKS devices is proven.

## Phase 4: copy back and finish

1. Mount tmppool/data read-only. `rsync -aHAXS --numeric-ids --info=progress2`
   into /data in tmux. Verify sizes and the same spot-check set.
2. Confirm in `bcachefs fs usage` that /data's extents are stripes on `hdd`
   and nothing from the OS subvolumes drifted there. Let reconcile finish
   (`bcachefs reconcile wait`, mindful of #920).
3. Start services. Fix ownership if anything shows up (ids were preserved).
4. Degraded-boot test with the owner: power off one HDD, reboot, confirm the
   root mounts and /data reads; power it back, confirm reconcile repairs.
5. Spin-down: `noatime` is set; configure `hd-idle` or `hdparm -S` for the
   three HDDs; confirm with `hdparm -C` after 30 idle minutes and with the
   Power dashboard's s0 numbers the next day. If reconcile keeps waking the
   array, revisit batching.
6. Cleanup in the repo: remove the root migration key and delete
   `~/.ssh/s0-migration` on fry; remove zfs root remnants
   (`services.zfs.*` for rpool, the import-ordering override no longer
   applies); enable `services.bcachefs.autoScrub`; teach
   `common/backups.nix` to snapshot bcachefs subvolumes; add an HDD spin-state
   metric if wanted. Update CLAUDE.md's architecture notes if they mention
   ZFS on s0.
7. `zpool export tmppool`, unplug the stepping stones, label them with the
   date, shelf. Keep for at least three months.

## Rollback by phase

- Phase 1: boot the USB stick; rpool is untouched. Wipe the NVMe partitions
  and retry.
- Phase 2: destroy tmppool; nothing else changed.
- Phase 3 after `zpool export`: `zpool import rpool` still works until the
  three drives are luksFormat'ed. After that, the data exists only on
  tmppool. Guard that drive set accordingly.
- Phase 4: the source is tmppool; copy again.

## Progress log

- 2026-10-10: plan written; prep branch adds the root key, the version pin
  and `boot.supportedFilesystems` for bcachefs on s0. Nothing executed.
