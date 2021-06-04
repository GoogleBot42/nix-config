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

  zerotier.enable = true;

  containers.jellyfin = {
    pia.enable = true;
    zerotier.enable = true;
    nixpkgs.pkgs = pkgs;

    services.radarr.enable = true;
    services.bazarr.enable = true;
    services.sonarr.enable = true;
    services.deluge.enable = true;
    services.deluge.web.enable = true;
  };

  security.acme.acceptTerms = true;
  security.acme.email = "letsencrypt+5@tar.ninja";
}
