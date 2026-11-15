# Build settings for the directly flashable Mono Gateway image.
#
# This uses NixOS's generic SD/eMMC image builder rather than the Raspberry Pi
# aarch64 image module so we do not accidentally ship Pi firmware. The board's
# NOR U-Boot boots the extlinux stanza from the root filesystem; nothing in
# this image is firmware.
#
# eMMC layout the board firmware expects: bytes 0-4 KiB hold the partition
# table, 4 KiB-32 MiB hold the eMMC copy of the firmware (PBL, FIP, U-Boot
# env, FMan microcode, recovery kernel), so no partition may start below
# 32 MiB and the image must never be written over that region. The 32 MiB
# gap below keeps the image's own bytes out of it; README.md has the dd
# invocation that skips it.
{ config, ... }:

{
  image.baseName = "nixos-leela-mono-gateway";

  sdImage = {
    rootVolumeLabel = "NIXOS_ROOT";
    expandOnBoot = true;
    # Raw image: it is written with dd straight from the recovery shell.
    compressImage = false;

    # The builder always makes partition 1 a FAT "firmware" partition. It is
    # unused on this board (U-Boot is told to read partition 2, the root
    # filesystem, see README.md) and kept minimal.
    firmwarePartitionOffset = 32;
    firmwareSize = 16;
    populateFirmwareCommands = "";

    populateRootCommands = ''
      mkdir -p ./files/boot
      ${config.boot.loader.generic-extlinux-compatible.populateCmd} \
        -c ${config.system.build.toplevel} \
        -d ./files/boot
    '';
  };

  assertions = [
    {
      assertion = config.boot.loader.generic-extlinux-compatible.enable;
      message = "The leela flash image requires generic-extlinux-compatible bootloader support.";
    }
    {
      assertion = config.fileSystems."/".device == "/dev/disk/by-label/${config.sdImage.rootVolumeLabel}";
      message = "The leela flash image root label must match fileSystems./.device.";
    }
  ];
}
