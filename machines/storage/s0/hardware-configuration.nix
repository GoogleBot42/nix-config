{ config, modulesPath, ... }:

{
  imports =
    [
      (modulesPath + "/installer/scan/not-detected.nix")
    ];

  # boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.memtest86.enable = true;
  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usb_storage" "uas" "sd_mod" "rtsx_pci_sdmmc" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  # firmware
  firmware.x86_64.enable = true;

  ### disks ###

  # zfs
  networking.hostId = "5e6791f0";
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.forceImportRoot = false;

  # luks
  remoteLuksUnlock.enable = true;
  boot.initrd.luks.devices."enc-pv1".device = "/dev/disk/by-uuid/d52e99a9-8825-4d0a-afc1-8edbef7e0a86";
  boot.initrd.luks.devices."enc-pv2".device = "/dev/disk/by-uuid/f7275585-7760-4230-97de-36704b9a2aa3";
  boot.initrd.luks.devices."enc-pv3".device = "/dev/disk/by-uuid/5d1002b8-a0ed-4a1c-99f5-24b8816d9e38";
  boot.initrd.luks.devices."enc-pv4".device = "/dev/disk/by-uuid/e2c7402a-e72c-4c4a-998f-82e4c10187bc";

  # mounts
  services.zfs.autoScrub.enable = true;
  services.zfs.trim.enable = true;
  fileSystems."/" =
    {
      device = "rpool/nixos/root";
      fsType = "zfs";
      options = [ "zfsutil" "X-mount.mkdir" ];
    };
  fileSystems."/var/lib" =
    {
      device = "rpool/nixos/var/lib";
      fsType = "zfs";
      options = [ "zfsutil" "X-mount.mkdir" ];
    };
  fileSystems."/var/log" =
    {
      device = "rpool/nixos/var/log";
      fsType = "zfs";
      options = [ "zfsutil" "X-mount.mkdir" ];
    };
  fileSystems."/boot" =
    {
      device = "/dev/disk/by-uuid/4FB4-738E";
      fsType = "vfat";
    };
  swapDevices = [ ];

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
