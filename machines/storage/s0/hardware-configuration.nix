{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [
      (modulesPath + "/installer/scan/not-detected.nix")
    ];

  # boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.memtest86.enable = true;
  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usb_storage" "uas" "sd_mod" "rtsx_pci_sdmmc" ];
  boot.initrd.kernelModules = [ "8021q" ]; # VLAN netdevs in initrd (remote LUKS unlock over vlan-main)
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  # firmware
  firmware.x86_64.enable = true;

  ### disks ###

  # One bcachefs filesystem (external UUID below) holds everything. Its
  # members are the two Solidigm NVMe drives (label ssd, every filesystem
  # default target, so the OS never leaves flash) and three WD HDDs (label
  # hdd), each a LUKS2 container. Per-directory options set with
  # `bcachefs set-file-option` (background_target=hdd, erasure_code) move
  # the data subvolume and the atticd NAR store (/var/lib/atticd) to the
  # HDDs as 2+1 stripes; everything else inherits the ssd defaults. Subvolumes are mounted with util-linux's
  # X-mount.subdir because bcachefs has no subvolume mount option of its own.
  boot.supportedFilesystems = [ "zfs" "bcachefs" ];
  boot.initrd.supportedFilesystems = [ "bcachefs" ];

  # zfs stays installed for the stepping-stone pool (tmppool) and the shelf
  # copy of the old rpool, both imported by hand when needed. No pool is
  # imported at boot, and `zfs mount -a` stays masked: those pools carry
  # datasets whose mountpoint properties point into the live tree.
  networking.hostId = "5e6791f0";
  boot.zfs.forceImportRoot = false;
  systemd.services.zfs-mount.enable = false;

  # bcachefs verifies checksums only when it reads, so a periodic scrub is
  # what finds latent damage before the other copy is needed. Monthly like
  # the ZFS scrub: it reads every block, which on the HDD tier is hours of
  # spinning. Run `bcachefs scrub /` by hand after anything eventful.
  services.bcachefs.autoScrub.enable = true;

  # luks. The remote-unlock module makes the initrd wait indefinitely for
  # devices (a passphrase can take a while to arrive); a dead member must not
  # inherit that, so each container gets its own bounded device timeout and
  # is non-fatal. A member that merely spins up slowly is still waited for.
  remoteLuksUnlock.enable = true;
  boot.initrd.luks.devices =
    let
      member = uuid: {
        device = "/dev/disk/by-uuid/${uuid}";
        crypttabExtraOpts = [ "nofail" "x-systemd.device-timeout=10min" ];
      };
    in
    {
      "enc-nvme-a" = member "3b8e47ca-a6b9-49e0-94ea-62a9493e8d18";
      "enc-nvme-b" = member "f3fc4503-7035-441c-80fc-c8287b39e92f";
      # The hdd tier: whole-disk LUKS2 on WD160EDGZ 2BJJ97DN, 2PGSVB9T and
      # 2BJ9K30N (ata3/4/5). 3JH0HT6G stays out as the spare and port ata6
      # stays empty: its link reset several times a day.
      "enc-hdd1" = member "eb98a01b-6652-4d54-9756-4057a154fa7d";
      "enc-hdd2" = member "97a052b8-d943-4f5a-80ea-676645f8e8c3";
      "enc-hdd3" = member "df4e42cd-b226-4460-b3f3-ac02bf3392ba";
    };

  # mounts
  fileSystems =
    let
      # degraded=yes: every block has two replicas (and /data has parity),
      # so a missing member must still boot this headless machine; the
      # default "ask" fails outright in the initrd. Waiting for
      # cryptsetup.target first gives every member its chance to be opened.
      # No mount timeout: after an unclean shutdown the journal replay over
      # 28 TB takes minutes, longer than systemd's default job limit, and a
      # timed-out root mount drops the initrd into its locked emergency
      # shell with no way forward.
      bcachefsSubvolume = subdir: {
        device = "UUID=3460f75d-5c8c-4511-a6dc-3a69659776f3";
        fsType = "bcachefs";
        options = [
          "noatime"
          "degraded=yes"
          "x-systemd.mount-timeout=infinity"
          "X-mount.subdir=${subdir}"
          "x-systemd.requires=cryptsetup.target"
          "x-systemd.after=cryptsetup.target"
        ];
      };
    in
    {
      "/" = bcachefsSubvolume "root";
      "/nix" = bcachefsSubvolume "nix";
      "/var" = bcachefsSubvolume "var";
      "/var/log" = bcachefsSubvolume "log";
      "/home" = bcachefsSubvolume "home";
      "/data" = bcachefsSubvolume "data";
      # ESP-A on the L4S drive is the live /boot; ESP-B on the L4Z drive is a
      # copy kept current by the loader hook below, so either NVMe boots.
      "/boot" = {
        device = "/dev/disk/by-uuid/0FFD-389D";
        fsType = "vfat";
        options = [ "umask=0077" ];
      };
      "/boot-mirror" = {
        device = "/dev/disk/by-uuid/0FFD-7D0B";
        fsType = "vfat";
        options = [ "umask=0077" "nofail" ];
      };
    };
  swapDevices = [ ];

  # Firmware entries are named so the BIOS shows which drive it boots from.
  # Entries are only ever added, never removed.
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.extraInstallCommands =
    let
      nvmeA = "/dev/disk/by-id/nvme-SOLIDIGM_SSDPFKKW020X7_SSC6N475610206L4S";
      nvmeB = "/dev/disk/by-id/nvme-SOLIDIGM_SSDPFKKW020X7_SSC6N475610206L4Z";
    in
    ''
      if ${pkgs.util-linux}/bin/mountpoint -q /boot-mirror; then
        ${pkgs.rsync}/bin/rsync -a --delete /boot/ /boot-mirror/
      fi
      ensure_entry() {
        ${pkgs.efibootmgr}/bin/efibootmgr | grep -qF "$1" || \
          ${pkgs.efibootmgr}/bin/efibootmgr --quiet --create --disk "$2" --part 1 \
            --label "$1" --loader '\EFI\systemd\systemd-bootx64.efi'
      }
      if [ -d /sys/firmware/efi/efivars ]; then
        ensure_entry "NixOS A (NVMe L4S)" ${nvmeA}
        ensure_entry "NixOS B (NVMe L4Z)" ${nvmeB}
      fi
    '';

  # The hdd tier holds only cold data, so the three WD drives spin down after
  # 30 idle minutes. The leading "-i 0" leaves every disk not named alone:
  # the NVMe pair and whatever hangs off USB. Drives are given as full
  # by-id paths: hd-idle resolves those to the kernel name, while a bare
  # by-id name matches nothing and silently disables the drive.
  systemd.services.hd-idle = {
    description = "spin down the idle hdd-tier drives";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.hd-idle}/bin/hd-idle -i 0 -c ata"
        + lib.concatMapStrings (serial: " -a /dev/disk/by-id/ata-WDC_WD160EDGZ-11B2DA0_${serial} -i 1800")
        [ "2BJJ97DN" "2PGSVB9T" "2BJ9K30N" ];
      Restart = "on-failure";
    };
  };

  ### networking ###

  networking = {
    useNetworkd = true;
    useDHCP = false;
    dhcpcd.enable = false;
  };

  boot.initrd.systemd.network = {
    enable = true;
    netdevs = {
      "40-vlan-main" = {
        netdevConfig = {
          Name = "vlan-main";
          Kind = "vlan";
        };
        vlanConfig.Id = 5;
      };
      "50-vlan-iot" = {
        netdevConfig = {
          Name = "vlan-iot";
          Kind = "vlan";
        };
        vlanConfig.Id = 2;
      };
      "50-vlan-mgmt" = {
        netdevConfig = {
          Name = "vlan-mgmt";
          Kind = "vlan";
        };
        vlanConfig.Id = 4;
      };
    };
    networks = {
      # eno1 — trunk port carrying all VLANs (no IP on the raw interface)
      "40-eno1" = {
        matchConfig.Name = "eno1";
        networkConfig = {
          VLAN = [ "vlan-main" "vlan-iot" "vlan-mgmt" ];
          LinkLocalAddressing = "no";
        };
        linkConfig.RequiredForOnline = "carrier";
      };

      "50-vlan-main" = {
        matchConfig.Name = "vlan-main";
        networkConfig.DHCP = "yes";
        dhcpV4Config.RouteMetric = 100;
        linkConfig.RequiredForOnline = "routable";
      };

      # VLAN 2 — IoT (cameras, smart home)
      "50-vlan-iot" = {
        matchConfig.Name = "vlan-iot";
        networkConfig.DHCP = "yes";
        dhcpV4Config = {
          UseGateway = false;
          RouteMetric = 200;
        };
        linkConfig.RequiredForOnline = "no";
      };

      # VLAN 4 — Management
      "50-vlan-mgmt" = {
        matchConfig.Name = "vlan-mgmt";
        networkConfig.DHCP = "yes";
        dhcpV4Config = {
          UseGateway = false;
          RouteMetric = 300;
        };
        linkConfig.RequiredForOnline = "no";
      };
    };
  };

  systemd.network = {
    enable = config.boot.initrd.systemd.network.enable;
    netdevs = config.boot.initrd.systemd.network.netdevs;
    networks = config.boot.initrd.systemd.network.networks;
  };

  powerManagement.cpuFreqGovernor = "schedutil";
}
