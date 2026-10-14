{ config, pkgs, lib, modulesPath, ... }:

# Mirrors machines/storage/s0/hardware-configuration.nix's disk stanza on two
# virtio disks with fixed identifiers (prep.sh creates them), so the initrd
# path NixOS generates is the one s0 will use. The LUKS key comes from a third
# raw disk so the guest boots unattended; s0 itself prompts.
let
  nvmeA = "/dev/disk/by-id/virtio-nvmeA";
  nvmeB = "/dev/disk/by-id/virtio-nvmeB";
  fsUuid = "33333333-3333-4333-8333-333333333333";
  bcachefsSubvolume = subdir: {
    device = "UUID=${fsUuid}";
    fsType = "bcachefs";
    # degraded=yes: every block has two replicas, so one surviving member
    # must still boot a headless machine (the default "ask" fails in the
    # initrd). Waiting for cryptsetup.target gives a slow member its chance.
    options = [
      "noatime"
      "degraded=yes"
      "X-mount.subdir=${subdir}"
      "x-systemd.requires=cryptsetup.target"
      "x-systemd.after=cryptsetup.target"
    ];
  };
  # A dead member must not hold the boot forever; a slow one gets this long.
  luksMember = uuid: {
    device = "/dev/disk/by-uuid/${uuid}";
    keyFile = "/dev/disk/by-id/virtio-luks-key";
    keyFileSize = 32;
    crypttabExtraOpts = [ "nofail" "x-systemd.device-timeout=45s" ];
  };
in
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  networking.hostName = "s0-rehearsal";
  system.stateVersion = "26.05";
  boot.kernelParams = [ "console=ttyS0,115200" ];
  services.getty.autologinUser = "root";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.extraInstallCommands = ''
    if ${pkgs.util-linux}/bin/mountpoint -q /boot-mirror; then
      ${pkgs.rsync}/bin/rsync -a --delete /boot/ /boot-mirror/
    fi
    ensure_entry() {
      ${pkgs.efibootmgr}/bin/efibootmgr | grep -qF "$1" || \
        ${pkgs.efibootmgr}/bin/efibootmgr --quiet --create --disk "$2" --part 1 \
          --label "$1" --loader '\EFI\systemd\systemd-bootx64.efi'
    }
    if [ -d /sys/firmware/efi/efivars ]; then
      ensure_entry "NixOS A (rehearsal)" ${nvmeA}
      ensure_entry "NixOS B (rehearsal)" ${nvmeB}
    fi
  '';

  boot.supportedFilesystems = [ "bcachefs" ];
  boot.initrd.supportedFilesystems = [ "bcachefs" ];
  boot.initrd.availableKernelModules = [ "virtio_pci" "virtio_blk" ];

  boot.initrd.luks.devices = {
    "enc-nvme-a" = luksMember "11111111-1111-4111-8111-111111111111";
    "enc-nvme-b" = luksMember "22222222-2222-4222-8222-222222222222";
  };

  fileSystems = {
    "/" = bcachefsSubvolume "root";
    "/nix" = bcachefsSubvolume "nix";
    "/var" = bcachefsSubvolume "var";
    "/var/log" = bcachefsSubvolume "log";
    "/home" = bcachefsSubvolume "home";
    "/boot" = { device = "/dev/disk/by-uuid/0A0A-0A0A"; fsType = "vfat"; options = [ "umask=0077" ]; };
    "/boot-mirror" = { device = "/dev/disk/by-uuid/0B0B-0B0B"; fsType = "vfat"; options = [ "umask=0077" "nofail" ]; };
  };

  environment.systemPackages = with pkgs; [ bcachefs-tools efibootmgr ];

  # Prints what the driver script checks, then powers off. A disk with serial
  # "hold" keeps the guest running so the driver can kill it mid-flight.
  systemd.services.rehearsal-report = {
    wantedBy = [ "multi-user.target" ];
    after = [ "multi-user.target" ];
    path = with pkgs; [ util-linux bcachefs-tools efibootmgr systemd coreutils ];
    serviceConfig = { Type = "oneshot"; StandardOutput = "journal+console"; StandardError = "inherit"; };
    script = ''
      echo "=== REHEARSAL REPORT $(date -Is) boot=$(journalctl --list-boots --no-pager | wc -l)"
      findmnt -no TARGET,SOURCE,FSTYPE,OPTIONS -t bcachefs,vfat
      bcachefs fs usage -h / | sed -n '1,12p'
      efibootmgr | grep -E "BootOrder|BootCurrent|NixOS"
      journalctl -b -k --no-pager | grep -iE "bcachefs|degraded|emergency" | tail -n 15
      systemctl --failed --no-legend || true
      echo "=== REPORT END"
      if [ -e /dev/disk/by-id/virtio-hold ]; then echo "holding"; sleep infinity; fi
      systemctl poweroff
    '';
  };
}
