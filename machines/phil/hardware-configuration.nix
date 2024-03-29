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
    device = "/dev/disk/by-uuid/d26c1820-4c39-4615-98c2-51442504e194";
    allowDiscards = true;
  };

  fileSystems."/" =
    {
      device = "/dev/disk/by-uuid/851bfde6-93cd-439e-9380-de28aa87eda9";
      fsType = "btrfs";
    };

  fileSystems."/boot" =
    {
      device = "/dev/disk/by-uuid/F185-C4E5";
      fsType = "vfat";
    };

  swapDevices =
    [{ device = "/dev/disk/by-uuid/d809e3a1-3915-405a-a200-4429c5efdf87"; }];

  networking.interfaces.enp0s6.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
