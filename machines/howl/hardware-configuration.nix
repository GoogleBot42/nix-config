{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.kernelPackages = pkgs.linuxPackages_latest;

  # boot
  boot.loader.systemd-boot.enable = true;
  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "thunderbolt" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ "dm-snapshot" ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  # firmware
  firmware.x86_64.enable = true;

  # disks
  remoteLuksUnlock.enable = true;
  boot.initrd.luks.devices."enc-pv" = {
    device = "/dev/disk/by-uuid/c801586b-f0a2-465c-8dae-532e61b83fee";
    allowDiscards = true;
  };
  fileSystems."/" =
    { device = "/dev/disk/by-uuid/95db6950-a7bc-46cf-9765-3ea675ccf014";
      fsType = "btrfs";
    };
  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/B087-2C20";
      fsType = "vfat";
      options = [ "fmask=0022" "dmask=0022" ];
    };
  swapDevices =
    [ { device = "/dev/disk/by-uuid/49fbdf62-eef4-421b-aac3-c93494afd23c"; }
    ];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlp1s0.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
