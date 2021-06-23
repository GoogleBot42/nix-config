{ config, ... }:

{
  # NixOS wants to enable GRUB by default
  boot.loader.grub.enable = false;
  # Enables the generation of /boot/extlinux/extlinux.conf
  boot.loader.generic-extlinux-compatible.enable = true;

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
    };
  };

  nix.flakes.enable = true;

  networking.interfaces.eth0.useDHCP = true;

  hardware.deviceTree.enable = true;
  hardware.deviceTree.overlays = [
    ./sopine-baseboard-ethernet.dtbo # fix pine64 clusterboard ethernet
  ];
}