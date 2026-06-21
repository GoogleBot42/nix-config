# Hardware defaults for the Mono Gateway Development Kit.
#
# The board is an aarch64 NXP Layerscape LS1046A system with 8 GB ECC RAM,
# 32 GB eMMC, 2x SFP+ 10GbE, and 3x RJ-45 1GbE. Mono's public kernel tree
# carries board-specific device-tree support that is not in mainline 6.12, so
# keep the NixOS 6.12 LTS kernel line but apply only Mono's minimal DTS/Makefile
# patch instead of importing their experimental NixOS/offload stack.
{ lib, pkgs, ... }:

{
  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;

  boot.kernelPackages = pkgs.linuxPackages_6_12;
  boot.kernelPatches = [
    {
      name = "mono-gateway-dk-dts";
      patch = ./patches/mono-gateway-dk-dts.patch;
    }
  ];

  boot.initrd.availableKernelModules = [
    "ahci_platform"
    "sdhci_of_esdhc"
    "mmc_block"
    "usb_storage"
  ];

  boot.kernelParams = [
    "console=ttyS0,115200n8"
    "earlycon=uart8250,mmio,0x21c0500"
  ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_ROOT";
    fsType = "ext4";
  };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
