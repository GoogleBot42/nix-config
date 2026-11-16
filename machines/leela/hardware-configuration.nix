# Hardware defaults for the Mono Gateway Development Kit.
#
# The board is an aarch64 NXP Layerscape LS1046A system with 8 GB ECC RAM,
# 32 GB eMMC, 2x SFP+ 10GbE, and 3x RJ-45 1GbE. The SoC is fully supported by
# the stock NixOS 6.12 LTS kernel (DPAA1 ethernet, esdhc eMMC, QSPI, i2c muxes
# are all enabled in the nixpkgs aarch64 config); only the board device tree is
# missing from mainline. Compile Mono's DTS separately against the kernel's
# source tree via hardware.deviceTree instead of boot.kernelPatches so the
# kernel itself stays a cache.nixos.org hit and never rebuilds.
{ config, lib, pkgs, ... }:

let
  kernel = config.boot.kernelPackages.kernel;

  # The kernel's dev output prunes .dtsi files, so pull the device tree
  # sources out of the kernel source tarball instead.
  kernelDtSource = pkgs.runCommand "linux-${kernel.version}-dt-source" { } ''
    mkdir $out
    tar -xf ${kernel.src} --strip-components=1 -C $out --wildcards \
      "linux-*/arch/arm64/boot/dts" \
      "linux-*/include/dt-bindings" \
      "linux-*/scripts/dtc/include-prefixes"
  '';

  # Mono's board DTS, unmodified from their public kernel tree. It includes
  # fsl-ls1046a.dtsi from the kernel source, so compile with the kernel's
  # dt include paths.
  monoDtb = pkgs.deviceTree.compileDTS {
    name = "mono-gateway-dk.dtb";
    dtsFile = ./mono-gateway-dk.dts;
    includePaths = [
      "${kernelDtSource}/scripts/dtc/include-prefixes"
      "${kernelDtSource}/arch/arm64/boot/dts/freescale"
    ];
  };
in
{
  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;

  boot.kernelPackages = pkgs.linuxPackages_6_12;

  # This is a base board device tree, not an overlay: mainline has no dtb for
  # this board that an overlay could apply to. Ship only the Mono dtb and name
  # it explicitly so the generated extlinux entries load it via FDT.
  hardware.deviceTree = {
    enable = true;
    dtbSource = pkgs.runCommand "mono-gateway-dk-dtbs" { } ''
      install -Dm444 ${monoDtb} $out/freescale/mono-gateway-dk.dtb
    '';
    name = "freescale/mono-gateway-dk.dtb";
  };

  boot.initrd.availableKernelModules = [
    "ahci_platform"
    "sdhci_of_esdhc"
    "mmc_block"
    "usb_storage"
  ];

  # The three 1G ports sit behind MaxLinear GPY115 PHYs on SGMII. The PHY is
  # attached when networkd brings the port up, and whichever PHY driver is
  # loaded at that moment wins: with only the generic driver the PHY reports
  # link but never passes a frame upstream. udev does not autoload mxl-gpy
  # for these devices, so load it before networkd runs.
  boot.initrd.kernelModules = [ "mxl_gpy" ];
  boot.kernelModules = [ "mxl_gpy" ];

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
