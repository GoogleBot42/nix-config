{ config, pkgs, lib, ... }:

{
  imports =[
    ./hardware-configuration.nix
    ../../common/common.nix
  ];

  # rzv5fm2vrmnbmffe3bgh2kxdpa66jwdjw57wallgw4j4q64kaknb55id.onion

  nix.flakes.enable = true;

  bios = {
    enable = true;
    device = "/dev/vda";
  };

  luks = {
    enable = true;
    device.path = "/dev/disk/by-uuid/e57ac752-bd99-421f-a3b9-0cfa9608a54e";
  };

  networking.hostName = "riko";

  networking.interfaces.ens3.useDHCP = true;

  security.acme.acceptTerms = true;
  security.acme.email = "letsencrypt+5@tar.ninja";

  services.nginx.enable = true;
  services.nginx.virtualHosts."riko.neet.dev" = {
    enableACME = true;
    forceSSL = true;
  };
}
