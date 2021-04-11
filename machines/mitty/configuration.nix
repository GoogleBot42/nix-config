{ config, pkgs, lib, ... }:

{
  imports =[
    ./hardware-configuration.nix
    ../common/common.nix
    ../common/boot/bios.nix
    ../common/boot/luks.nix
    ../common/server/nginx.nix
  ];

  # cuxhh3ei2djpgf2zdkboceuhaxavgr3ipu3d7a2swx4giy2wosfxspyd.onion

  boot.loader.grub.device = "/dev/vda";
  networking.hostName = "mitty";
  boot.initrd.luks.devices.enc-pv.device = "/dev/disk/by-uuid/6dcf23ea-cb5e-4329-a88b-832209918c40";

  networking.wireless.enable = false;
  networking.useDHCP = false;
  networking.interfaces.ens3.useDHCP = true;

  security.acme.acceptTerms = true;
  security.acme.email = "letsencrypt+5@tar.ninja";
}
