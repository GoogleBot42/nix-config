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
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  # firmware
  firmware.x86_64.enable = true;

  ### disks ###

  # zfs
  networking.hostId = "5e6791f0";
  boot.supportedFilesystems = [ "zfs" ];
  boot.kernelPackages = config.boot.zfs.package.latestCompatibleLinuxPackages;

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

  networking.vlans = {
    iot = {
      id = 2;
      interface = "eth1";
    };
  };

  powerManagement.cpuFreqGovernor = "powersave";
}
