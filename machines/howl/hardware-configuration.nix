{ config, lib, pkgs, modulesPath, nixos-hardware, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    nixos-hardware.nixosModules.framework-13-7040-amd
  ];

  # boot.kernelPackages = pkgs.linuxPackages_6_14;
  boot.kernelPackages = pkgs.linuxPackages_6_13;

  hardware.framework.amd-7040.preventWakeOnAC = true;
  services.fwupd.enable = true;
  # fingerprint reader has initially shown to be more of a nuisance than a help
  # it makes sddm log in fail most of the time and take several minutes to finish
  services.fprintd.enable = false;

  # boot
  boot.loader.systemd-boot.enable = true;
  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "thunderbolt" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ "dm-snapshot" ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  # thunderbolt
  services.hardware.bolt.enable = true;

  # firmware
  firmware.x86_64.enable = true;

  # disks
  remoteLuksUnlock.enable = true;
  boot.initrd.luks.devices."enc-pv" = {
    device = "/dev/disk/by-uuid/2e4a6960-a6b1-40ee-9c2c-2766eb718d52";
    allowDiscards = true;
  };
  fileSystems."/" =
    {
      device = "/dev/disk/by-uuid/1f62386c-3243-49f5-b72f-df8fc8f39db8";
      fsType = "btrfs";
    };
  fileSystems."/boot" =
    {
      device = "/dev/disk/by-uuid/F4D9-C5E8";
      fsType = "vfat";
      options = [ "fmask=0022" "dmask=0022" ];
    };
  swapDevices =
    [{ device = "/dev/disk/by-uuid/5f65cb11-2649-48fe-9c78-3e325b857c53"; }];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlp1s0.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
