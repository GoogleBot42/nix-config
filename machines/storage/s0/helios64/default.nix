{ config, pkgs, lib, ... }:

{
  imports = [
    ./modules/fancontrol.nix
    ./modules/heartbeat.nix
    ./modules/ups.nix
    ./modules/usbnet.nix
  ];

  boot.kernelParams = lib.mkAfter [
    "console=ttyS2,115200n8"
    "earlyprintk"
    "earlycon=uart8250,mmio32,0xff1a0000"
  ];

  # disabled because, when enabled, bcachefs wants a different but still adequate kernel
  # boot.kernelPackages = pkgs.linuxKernel.packages.linux_5_16;

  # bcachefs kernel is 5.15. but need a patch that is only in 5.16
  # Patch the device tree to add support for getting the cpu thermal temp
  hardware.deviceTree.enable = true;
  hardware.deviceTree.overlays = [
    ./helios64-cpu-temp.dtbo
  ];
}
