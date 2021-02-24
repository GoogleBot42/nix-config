{ config, pkgs, lib, ... }:

{
  imports =[
    ./hardware-configuration.nix
    ../common/common.nix
    ../common/boot/bios.nix
    ../common/boot/luks.nix
#   ../common/server/nsd.nix
    ../common/server/nginx.nix
    ../common/server/thelounge.nix
    ../common/server/mumble.nix
    ../common/server/gitlab.nix
    ../common/server/video-stream.nix
    ../common/server/hydra.nix
  ];

  boot.loader.grub.device = "/dev/sda";
  networking.hostName = "neetdev";
  boot.initrd.luks.devices.enc-pv.device = "/dev/disk/by-uuid/06f6b0bf-fe79-4b89-a549-b464c2b162a1";

  networking.wireless.enable = false;
  networking.useDHCP = false;
  networking.interfaces.eno1.useDHCP = true;

  security.acme.acceptTerms = true;
  security.acme.email = "letsencrypt+5@tar.ninja";
}

