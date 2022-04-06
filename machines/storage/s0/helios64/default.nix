{ config, pkgs, lib, ... }:

{
  imports = [
    ./modules/fancontrol.nix
    ./modules/heartbeat.nix
    ./modules/ups.nix
  ];

  boot.kernelParams = lib.mkAfter [
    "console=ttyS2,115200n8"
    "earlycon=uart8250,mmio32,0xff1a0000"
  ];

  # Required for rootfs on sata
  boot.initrd.availableKernelModules = [
    "pcie-rockchip-host"
    "phy-rockchip-pcie"
    "phy-rockchip-usb"
  ];

  # bcachefs kernel is 5.15. but need patches that are only in 5.16+
  # Patch the device tree to add support for getting the cpu thermal temp
  hardware.deviceTree.enable = true;
  hardware.deviceTree.kernelPackage = pkgs.linux_latest;
}
