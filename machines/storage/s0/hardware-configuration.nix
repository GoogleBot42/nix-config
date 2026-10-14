{ config, pkgs, modulesPath, ... }:

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

  # One bcachefs filesystem (external UUID below) holds the OS. Its members
  # are the two Solidigm NVMe drives, each a LUKS2 container, mirrored at two
  # replicas with every target on the "ssd" label; the HDDs join it later as
  # the background target for /data. Subvolumes are mounted with util-linux's
  # X-mount.subdir because bcachefs has no subvolume mount option of its own.
  boot.supportedFilesystems = [ "zfs" "bcachefs" ];
  boot.initrd.supportedFilesystems = [ "bcachefs" ];

  # zfs: rpool still carries /data until the HDDs are re-formatted
  networking.hostId = "5e6791f0";
  boot.zfs.forceImportRoot = false;
  services.zfs.autoScrub.enable = true;
  services.zfs.trim.enable = true;

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
      "enc-pv1" = member "d52e99a9-8825-4d0a-afc1-8edbef7e0a86";
      "enc-pv2" = member "f7275585-7760-4230-97de-36704b9a2aa3";
      "enc-pv3" = member "5d1002b8-a0ed-4a1c-99f5-24b8816d9e38";
      "enc-pv4" = member "e2c7402a-e72c-4c4a-998f-82e4c10187bc";
    };

  # mounts
  fileSystems =
    let
      # degraded=yes: every block has two replicas (and /data will have
      # parity), so a missing member must still boot this headless machine;
      # the default "ask" fails outright in the initrd. Waiting for
      # cryptsetup.target first gives every member its chance to be opened.
      bcachefsSubvolume = subdir: {
        device = "UUID=3460f75d-5c8c-4511-a6dc-3a69659776f3";
        fsType = "bcachefs";
        options = [
          "noatime"
          "degraded=yes"
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
      "/data" = {
        device = "rpool/nixos/data";
        fsType = "zfs";
        options = [ "zfsutil" "X-mount.mkdir" ];
      };
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
