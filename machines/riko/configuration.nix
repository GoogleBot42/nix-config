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
    device.path = "/dev/disk/by-uuid/60051e7a-c2fe-4065-9ef0-110aaac78f0c";
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

  services.matrix = {
    enable = true;
    host = "neet.space";
    enable_registration = false;
    element-web = {
      enable = true;
      host = "chat.neet.space";
    };
    jitsi-meet = {
      enable = true;
      host = "meet.neet.space";
    };
    turn = {
      host = "turn.neet.space";
      secret = "a8369a0e96922abf72494bb888c85831b";
    };
  };
}