# Build settings for the directly flashable Mono Gateway image.
#
# This uses NixOS's generic SD/eMMC image builder rather than the Raspberry Pi
# aarch64 image module so we do not accidentally ship Pi firmware. The Mono
# Gateway DK is expected to boot via its board firmware/U-Boot in NOR and load
# the extlinux stanza from the root filesystem. If field testing shows that the
# board instead requires an eMMC-resident vendor U-Boot image, add that package
# here and write it from sdImage.postBuildCommands at the vendor-documented
# offset.
{ config, ... }:

{
  image.baseName = "nixos-leela-mono-gateway";

  sdImage = {
    rootVolumeLabel = "NIXOS_ROOT";
    expandOnBoot = true;

    # Keep enough room before the first partition for board firmware/U-Boot
    # layouts that reserve raw sectors. The current image relies on the Mono
    # Gateway DK's existing NOR U-Boot to load /boot/extlinux from the rootfs;
    # no Raspberry Pi firmware files belong on this board.
    firmwarePartitionOffset = 16;
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
