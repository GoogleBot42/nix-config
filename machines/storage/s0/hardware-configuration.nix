{ modulesPath, ... }:

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
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  # firmware
  firmware.x86_64.enable = true;

  ### disks ###

  # zfs
  networking.hostId = "5e6791f0";
  boot.supportedFilesystems = [ "zfs" ];

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

  systemd.network.enable = true;
  networking = {
    useNetworkd = true;
    useDHCP = false;
    dhcpcd.enable = false;
  };

  # eno1 — native VLAN 5 (main), default route, internet
  # useDHCP generates the base 40-eno1 networkd unit and drives initrd DHCP for LUKS unlock.
  networking.interfaces."eno1".useDHCP = true;
  systemd.network.networks."40-eno1" = {
    dhcpV4Config.RouteMetric = 100; # prefer eno1 over VLAN interfaces for default route
    linkConfig.RequiredForOnline = "routable"; # wait-online succeeds once eno1 has a route
  };

  # eno2 — trunk port (no IP on the raw interface)
  systemd.network.networks."40-eno2" = {
    matchConfig.Name = "eno2";
    networkConfig = {
      VLAN = [ "vlan-iot" "vlan-mgmt" ];
      LinkLocalAddressing = "no";
    };
    linkConfig.RequiredForOnline = "carrier";
  };

  # VLAN 2 — IoT (cameras, smart home)
  systemd.network.netdevs."50-vlan-iot".netdevConfig = { Name = "vlan-iot"; Kind = "vlan"; };
  systemd.network.netdevs."50-vlan-iot".vlanConfig.Id = 2;
  systemd.network.networks."50-vlan-iot" = {
    matchConfig.Name = "vlan-iot";
    networkConfig.DHCP = "yes";
    dhcpV4Config = {
      UseGateway = false;
      RouteMetric = 200;
    };
    linkConfig.RequiredForOnline = "no";
  };

  # VLAN 4 — Management
  systemd.network.netdevs."50-vlan-mgmt".netdevConfig = { Name = "vlan-mgmt"; Kind = "vlan"; };
  systemd.network.netdevs."50-vlan-mgmt".vlanConfig.Id = 4;
  systemd.network.networks."50-vlan-mgmt" = {
    matchConfig.Name = "vlan-mgmt";
    networkConfig.DHCP = "yes";
    dhcpV4Config = {
      UseGateway = false;
      RouteMetric = 300;
    };
    linkConfig.RequiredForOnline = "no";
  };

  powerManagement.cpuFreqGovernor = "schedutil";
}
