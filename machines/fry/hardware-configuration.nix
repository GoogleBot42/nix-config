{ config, lib, pkgs, modulesPath, nixos-hardware, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    nixos-hardware.nixosModules.framework-amd-ai-300-series
  ];

  boot.kernelPackages = pkgs.linuxPackages_latest;

  services.fwupd.enable = true;

  # boot
  boot.loader.systemd-boot.enable = true;
  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "thunderbolt" "usb_storage" "sd_mod" "r8169" ];
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
    device = "/dev/disk/by-uuid/d4f2f25a-5108-4285-968f-b24fb516d4f3";
    allowDiscards = true;
  };
  fileSystems."/" =
    { device = "/dev/disk/by-uuid/a8901bc1-8642-442a-940a-ddd3f428cd0f";
      fsType = "btrfs";
    };
  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/13E5-C9D4";
      fsType = "vfat";
      options = [ "fmask=0022" "dmask=0022" ];
    };
  swapDevices =
    [ { device = "/dev/disk/by-uuid/03356a74-33f0-4a2e-b57a-ec9dfc9d85c5"; }
    ];

  # Ensures that dhcp is active during initrd (Network Manager is used post boot)
  boot.initrd.network.udhcpc.enable = true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
