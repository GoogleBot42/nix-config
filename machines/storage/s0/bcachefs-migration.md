# s0: migrate from ZFS raidz1 to one bcachefs filesystem

## Handoff (state as of 2026-10-15 21:40)

Read this first. Everything below it is the full plan, decisions and history.

**Where things stand**

- s0 runs the ZFS-root system (generation 476, nixpkgs 20261011.7fd4004,
  deployed from master 7bcd0a1) booted from the USB stick. BootOrder: stick
  first (0001,0000,0005,0006,0007,0008,0002). Firmware entries 0005/0006 are
  the named NVMe entries, 0003/0004/0007/0008 are bootctl/firmware extras
  pointing at the NVMe ESPs; harmless, tidy them after cutover.
- master is **safe to deploy to s0** again: it carries the ZFS disk stanza.
  The bcachefs-root stanza is exactly one commit on `feat/s0-nvme-root`
  (agent fork, rebased on master) and is applied only inside the cutover
  procedure. Never merge it to master before s0 boots from the NVMe tier;
  see the 2026-10-15 incident entry in the progress log for what happens
  otherwise. The stanza also masks `zfs-mount.service` and mounts
  `/var/lib/atticd` from rpool; both are required, see the two last
  gotchas.
- The cutover closure is built from that branch and already on s0; its
  store path is in `/root/migration/cutover-closure.txt`. Rebuild and
  re-copy if master or the branch moves before the cutover.
- Observability from master is live on s0 and kif: `bcachefs-health-check`
  and `bcachefs-metrics` timers, spooled ntfy, the bcachefs dashboard and
  three Grafana rules, all alerting to ntfy topic `service-failures`.
- NVMe filesystem (UUID 3460f75d-5c8c-4511-a6dc-3a69659776f3, LUKS
  `enc-nvme-a`/`enc-nvme-b`, both with the owner's passphrase and the
  throwaway key): healthy, 0 errors, 677 GB used, NOT mounted and its LUKS
  closed. It holds the OS copy from the 11th plus ~170 files services wrote
  into it during the broken switch on the 15th; the cutover's
  `rsync --delete` from fresh snapshots replaces all of that. Its loader
  (ESP-A, mirrored to ESP-B) has generation 474 from Step 3.
- Stepping stones (`tmppool`, 16+4+4 TB over USB, LUKS with both keys):
  imported, ONLINE, `/data` received, second scrub finished clean
  2026-10-15 01:02. Snapshot `mig2` on both pools still holds the 1.2 TB the
  owner trashed from Transmission's completed downloads; keep until told.
- 32 stale partial torrents (51 GB) remain in `/var/lib/transmission/
  .incomplete` for the owner to trash.
- Hardware: `ata6` (drive 3JH0HT6G) resets its SATA link several times a
  day; SMART clean; candidate for the drive left out.

**Access**

- `ssh -i ~/.ssh/s0-migration -o HostKeyAlias=s0 root.koi-bebop.ts.net`
  (or `root.168.1.2`). Bare `s0` sometimes resolves to a rejected VLAN
  lease; see the deploy skill.
- Throwaway LUKS key: `secrets/s0-migration-luks-passphrase.age` (canonical),
  fry `~/.ssh/s0-migration-luks.key`, s0 `/root/s0-migration-luks.key`.
- Rehearsal kit: `machines/storage/s0/rehearsal/` (passed all four tests).

**Next: Step 5, the cutover, owner present, ~1 h of /var/lib downtime**

1. Owner trashes the 32 partials (optional) and confirms restic is green.
2. Build s0 from `feat/s0-nvme-root` (rebased on master), `nix copy` the
   closure to s0, note the path in `/root/migration/cutover-closure.txt`.
   Do not deploy it. (Done 2026-10-15 23:00; redo only if either moves.)
3. `/root/migration/cutover-1-open-mount.sh`: opens the NVMe LUKS with the
   throwaway key and mounts the whole tree at /mnt/s0fs. Idempotent. (The
   three scripts are versioned in `machines/storage/s0/cutover/`.)
4. `cutover-2-stop-snapshot-rsync.sh --dry-run` first (services keep
   running, snapshot @os3dry, `rsync -n`, snapshot destroyed), read the
   counts, then the same without the flag: stops the 24 writer units and
   the three restic timers, snapshots `rpool/nixos@os3`, rsyncs
   `-aHAXS --numeric-ids --delete` from the snapshots (root minus
   nix/var/home/data/boot/tmp/mnt; root's /var minus lib/log; nix; log;
   home; var/lib minus atticd). Logs `rsync-cutover-*.log`. Downtime
   starts here.
5. `cutover-3-install-bootorder.sh`: bind-mounts the tree at /mnt/target
   with both ESPs, `nixos-install --system <closure> --no-root-passwd
   --no-channel-copy`, checks the ESP mirror, unmounts and closes the NVMe
   LUKS, saves the old BootOrder, sets `0005,0006,0001,0000,0002` and prints
   the reboot command. It never reboots by itself.
6. Reboot. Unlock over the usual remote path (six LUKS devices, one
   passphrase). Verify mounts (`findmnt -t zfs` lists only `/data` and
   `/var/lib/atticd`; `/`, `/nix`, `/var`, `/var/log`, `/home` are
   bcachefs), services, Gatus, `bcachefs fs usage`, then
   `bcachefs scrub /`. Soak for days. Then merge `feat/s0-nvme-root`.
7. Rollback at any point before Phase 3: BIOS boot menu -> USB stick ->
   latest ZFS generation.


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
- **ZFS auto-mount over bcachefs.** The old OS datasets (`rpool/nixos/root`,
  `var/lib`, `var/log`, `home`, `var/lib/atticd`) keep `canmount=on` and
  their `mountpoint` properties so the USB-stick rollback generation still
  boots, and ZFS on Linux mounts over non-empty directories by default
  (`overlay=on`). NixOS's `zfs-mount.service` runs `zfs mount -a` before
  `local-fs.target`, which on the NVMe-root system would layer every old
  dataset over its bcachefs counterpart, root included. The branch masks
  that unit (`systemd.services.zfs-mount.enable = false`) and mounts the
  two datasets the new system still needs, `/data` and `/var/lib/atticd`,
  through `fileSystems` only. Never "fix" this by changing the dataset
  properties instead: that silently breaks the rollback path, whose `/home`
  and `/var/lib/atticd` are mounted by `zfs mount -a` alone. After the
  first NVMe boot, `findmnt -t zfs` must list exactly `/data` and
  `/var/lib/atticd`.
- **atticd's store is still on rpool.** The OS copy excluded
  `/var/lib/atticd` (343 GB of NARs, reproducible) and the branch mounts the
  ZFS dataset there instead. atticd's metadata is in PostgreSQL on the NVMe
  tier, so an empty store would make every cached path fail, not just miss.
  Phase 3 destroys rpool: before its Step 1, either copy the dataset to a
  directory on the bcachefs tree (fits: ~1 TB free at two replicas) or
  drop the cache and reset the PostgreSQL database with it.

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
   - `/boot` on the L4S drive's ESP by its new UUID, the L4Z drive's ESP
     mounted at `/boot-mirror`, and `boot.loader.systemd-boot.extraInstallCommands`
     doing two things after every rebuild: `rsync -a --delete /boot/ /boot-mirror/`,
     and an idempotent `efibootmgr` pass that guarantees two firmware entries,
     labelled **"NixOS A (NVMe L4S)"** and **"NixOS B (NVMe L4Z)"**, each
     pointing at `\EFI\systemd\systemd-bootx64.efi` on its own ESP (create
     only when an entry with that label is missing; never delete entries you
     did not create). The owner asked for distinguishable A/B names in the
     BIOS. This needs `boot.loader.efi.canTouchEfiVariables = true` on s0,
     which is off today (the USB stick boots through the nameless fallback
     path). Set the order A, B in firmware once, with the owner present.
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
10. Run `bcachefs scrub /` once the system is up and let it finish (minutes
    on the NVMe tier); zero errors is part of the soak criteria.
11. **Run on this for several days before Phase 3.** Record the date.

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
   (`bcachefs reconcile wait`, mindful of #920), then run `bcachefs scrub /`
   over the whole filesystem (hours on the HDDs) before starting services;
   the monthly timer (`services.bcachefs.autoScrub`) takes over from there.
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
   applies); teach
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
  - **Passphrase copies.** The age file above is the canonical copy. Working
    copies: fry `~/.ssh/s0-migration-luks.key` (persistent), s0
    `/root/s0-migration-luks.key` (on rpool, so it disappears in Phase 3)
    and s0 `/run/s0-migration-luks.key` (tmpfs, gone after a reboot).
    Re-create a working copy with `agenix -d` before opening anything.
- 2026-10-11 22:50: the three stepping stones moved into a 3-bay USB 3.1
  enclosure (three VIA VL817 bridges, 512-byte logical sectors; by-id names
  come from the bridges, so identify drives by `lsblk -dno NAME,SERIAL` or
  LUKS UUID). Both IronWolf 4 TB drives (ZGY79T43, ZGY68DX1; owner confirmed
  disposable) are LUKS `s0-stone4a` f92d408f-74b3-4f3b-9770-d555220a5478 and
  `s0-stone4b` 13884b48-876d-4aea-bd84-0c1080e44ca3 and were added to
  `tmppool`, now 21.8 TiB over enc-stone16/4a/4b. The send was stopped for the
  move (resume token kept), then resumed with `zfs send -t <token> | zfs recv
  -s -u tmppool/data` at ~350 MB/s; projected to finish around 04:00 on
  2026-10-12, after which: scrub `tmppool`, resume the OS rsync.
- 2026-10-12: **bulk copies done.** `zfs send` of `/data@mig1` completed
  06:15 (EXIT=0, same snapshot guid on both sides, 17.4 TiB, resume token
  cleared) after two enclosure dropouts caused by the enclosure's USB cable;
  a shorter cable fixed it. Recovery from a dropout without rebooting is
  `/root/migration/reattach-stones.sh` (rebuilds the crypt tables from the
  LUKS headers, clears the pool), then restart the send from the resume
  token. `zpool scrub tmppool` started 06:15, 0 errors so far, finishing
  around 06:00 on the 13th; check `zpool status tmppool` before trusting the
  copy. The OS rsync finished 21:37, all six jobs EXIT=0. On the NVMe
  filesystem: 2.71 TB used at two replicas, 73% per device. **1.1 TB of it is
  `/var/lib/transmission/.incomplete`, 34 stale partial torrents from 2023 to
  2026-08**; the owner decides whether they are deleted or moved to /data
  before the cutover, but they do not belong on the SSD tier. Frigate's
  StateDirectory is tiny; its recordings are not under /var/lib. Hardware:
  the SATA link of `ata6` (drive 3JH0HT6G) resets several times a day and has
  for a month; SMART is clean on all four drives; see the hard-reset notes.
  Name resolution: use `s0.koi-bebop.ts.net` for ssh; the bare name `s0`
  sometimes resolves through the router to s0's management-VLAN lease, which
  the router rejects.
- 2026-10-14 02:00: **Phase 1 Steps 1 and 2 done.** Branch `feat/s0-nvme-root`
  carries the new disk stanza and `machines/storage/s0/rehearsal/`. Findings
  the stanza now encodes: bcachefs's default `degraded=ask` fails a
  non-interactive initrd mount outright, so the bcachefs mounts carry
  `degraded=yes` (all data has two replicas), `x-systemd.requires/after=
  cryptsetup.target` so every member is opened before mounting, and each
  LUKS container is `nofail` with `x-systemd.device-timeout=10min` so a dead
  member times out rather than inheriting the remote-unlock module's
  indefinite device wait. Rehearsal results (QEMU, OVMF): unattended install
  OK; normal boot OK; boot with one member absent OK (firmware fell through
  to the other named entry, LUKS wait timed out, root mounted degraded on one
  member); boot with the member returned OK (both members back, degraded
  writes re-replicate). Harmless noise to expect on s0: `bcachefs (/dev/dm-N):
  error reading superblock: EBUSY` from the module's native-encryption unlock
  probe. Rehearsal gotchas: the fleet ISO is BIOS-only
  (`image.modules.iso.isoImage.makeEfiBootable`), services must not write
  /dev/ttyS0 directly, the prep PATH needs nixos-install-tools, nix and
  efibootmgr. The loader hook registers the named entries at install time
  and puts the newest first in BootOrder, so on s0 the order must be put
  back to the USB stick right after Step 3 and only switched to "NixOS A" at
  the Step 5 reboot. Second scrub of tmppool running.
- 2026-10-14 02:20: **Step 3 done.** The s0 closure built from this branch
  (`nixos-system-s0-26.11.20261010.6510408`, store hash n4djkhl2…) was
  `nix copy`'d to s0 and `nixos-install --system … --root /mnt/target`
  ran against the subvolume tree (root, nix, var, log, home) with ESP-A at
  /boot and ESP-B at /boot-mirror. Result: systemd-boot installed on ESP-A,
  eight loader entries, mirror identical; system profile at generation 474;
  firmware entries Boot0005 "NixOS A (NVMe L4S)" and Boot0006 "NixOS B (NVMe
  L4Z)" created, plus bootctl's own "Linux Boot Manager"/"Fallback" entries
  for ESP-A. BootOrder restored to USB stick first (0001,0000,0002,0005,0006),
  saved in /root/migration/bootorder-before.txt. The target tree is
  unmounted again; /mnt/s0fs stays mounted. Step 4 (owner's LUKS passphrase
  on both NVMe containers and the stepping stones) was done on the 13th.
  **Remaining for Phase 1 (Step 5, owner present):** merge this branch, stop
  the /var/lib writers, snapshot, incremental rsync with `--delete` of root,
  var, nix, log and home from the new snapshots into the tree, re-run
  `nixos-install --system` with the then-current closure, set BootOrder to
  Boot0005 first (`efibootmgr -o 0005,0006,0001,0000,0002`), reboot, unlock
  over the usual remote path, verify, then soak for days.
- 2026-10-15 (day): **incident, bcachefs stanza deployed to the running s0.**
  With the stanza on master, deploying master mounted the NVMe copies of
  /nix and /var over the live ZFS ones mid-switch and rebooted s0 into an
  initrd that mounts the NVMe root. s0 is back on the USB stick and the
  ZFS root; master carries the ZFS disk stanza again (7bcd0a1, generation
  476) and the bcachefs stanza lives only on `feat/s0-nvme-root`. Lesson, now in
  the handoff: a root-filesystem change is applied by `nixos-install` into the new tree
  during the cutover, never by `nixos-rebuild switch` on the running box.
- 2026-10-15 23:00: **Step 5 prep done, cutover not started.** Branch
  rebased on master. Reviewing the new system's unit set found two gaps
  (both now gotchas): `zfs-mount.service` would have run `zfs mount -a` at
  the first NVMe boot and layered the old root/var-lib/log/home datasets
  over the bcachefs mounts (they keep `canmount=on` for the rollback
  generation, and `overlay=on` is the ZFS default), and atticd's 343 GB
  store dataset was neither copied nor mounted. The branch masks
  `zfs-mount.service` and mounts `rpool/nixos/var/lib/atticd` via
  `fileSystems`. Verified in the built closure: `zfs-mount.service ->
  /dev/null`, fstab has `/data` and `/var/lib/atticd`, `zfs-import-rpool`
  is ordered before both mount units. Closure copied to s0, path in
  `/root/migration/cutover-closure.txt`. restic: all three groups green;
  s0 healthy on generation 476; NVMe LUKS closed; 49 GB of partials remain
  in Transmission's incomplete directory.
