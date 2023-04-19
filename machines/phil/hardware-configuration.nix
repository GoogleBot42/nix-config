# Do not modify this file!  It was generated by ‘nixos-generate-config’
# and may be overwritten by future invocations.  Please make changes
# to /etc/nixos/configuration.nix instead.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [
      (modulesPath + "/profiles/qemu-guest.nix")
    ];

  # because grub just doesn't work for some reason
  boot.loader.systemd-boot.enable = true;

  remoteLuksUnlock.enable = true;
  remoteLuksUnlock.enableTorUnlock = false;

  boot.initrd.availableKernelModules = [ "xhci_pci" ];
  boot.initrd.kernelModules = [ "dm-snapshot" ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  boot.initrd.luks.devices."enc-pv" = {
    device = "/dev/disk/by-uuid/9f1727c7-1e95-47b9-9807-8f38531eed47";
    allowDiscards = true;
  };

  fileSystems."/" =
    {
      device = "/dev/mapper/vg-root";
      fsType = "btrfs";
    };

  fileSystems."/boot" =
    {
      device = "/dev/disk/by-uuid/EC6B-53AA";
      fsType = "vfat";
    };

  swapDevices =
    [{ device = "/dev/disk/by-uuid/b916094f-cf2a-4be7-b8f1-674ba6473061"; }];

  networking.interfaces.enp0s6.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
