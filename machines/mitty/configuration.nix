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

  # # icecast
  # services.icecast = {
  #   enable = true;
  #   hostname = "mitty.neet.dev";
  #   listen.port = 8000;
  #   admin.password = builtins.readFile /secret/icecast.password;
  # };
  networking.firewall.allowedTCPPorts = [ 1935 ];
  services.peertube = {
    enable = true;
    configFile = ./peertube.yaml;
  };
  services.postfix.enable = true;
  services.redis.enable = true;
  services.nginx.virtualHosts."mitty.neet.dev" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://localhost:9000";
    };
  };

  security.acme.acceptTerms = true;
  security.acme.email = "letsencrypt+5@tar.ninja";
}
