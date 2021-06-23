{ config, pkgs, lib, ... }:

{
  imports =[
    ./hardware-configuration.nix
  ];

  # uxzq63kr2uuwutpaqjna2sg4gnk3p65e5bkvedzx5dsxx2mvxhjm7fid.onion

  nix.flakes.enable = true;

  bios = {
    enable = true;
    device = "/dev/vda";
  };

  luks = {
    enable = true;
    device.path = "/dev/disk/by-uuid/e57ac752-bd99-421f-a3b9-0cfa9608a54e";
  };

  networking.hostName = "nanachi";

  networking.interfaces.ens3.useDHCP = true;

  services.icecast = {
    enable = true;
    hostname = "nanachi.neet.dev";
    mount = "stream.mp3";
    fallback = "fallback.mp3";
  };

  security.acme.acceptTerms = true;
  security.acme.email = "letsencrypt+5@tar.ninja";

  services.nginx.enable = true;
  services.nginx.virtualHosts."nanachi.neet.dev" = {
    enableACME = true;
    forceSSL = true;
    root = "/var/www/tmp";
  };
}
