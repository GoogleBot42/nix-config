{ config, pkgs, lib, ... }:

{
  imports =[
    ./hardware-configuration.nix
    ../../common/common.nix
  ];

  # cuxhh3ei2djpgf2zdkboceuhaxavgr3ipu3d7a2swx4giy2wosfxspyd.onion

  nix.flakes.enable = true;

  bios = {
    enable = true;
    device = "/dev/vda";
  };

  luks = {
    enable = true;
    device.path = "/dev/disk/by-uuid/6dcf23ea-cb5e-4329-a88b-832209918c40";
  };

  networking.hostName = "mitty";

  networking.interfaces.ens3.useDHCP = true;

  services.nginx.enable = true;

  # icecast
  services.icecast = {
    enable = true;
    hostname = "mitty.neet.dev";
    mount = "stream.mp3";
  };

  services.nginx.stream =
  {
    enable = true;
    hostname = "mitty.neet.dev";
  };

  services.zerobin = {
    enable = true;
    host = "paste.neet.cloud";
  };

  security.acme.acceptTerms = true;
  security.acme.email = "letsencrypt+5@tar.ninja";
}
