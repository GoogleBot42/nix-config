{ config, pkgs, lib, ... }:

{
  imports =[
    ./hardware-configuration.nix
  ];

  networking.hostName = "ponyo";

  firmware.x86_64.enable = true;
  bios = {
    enable = true;
    device = "/dev/sda";
  };

  luks = {
    enable = true;
    device.path = "/dev/disk/by-uuid/4cc36be4-dbff-4afe-927d-69bf4637bae2";
  };

  system.autoUpgrade.enable = true;

  services.zerotierone.enable = true;

  services.thelounge = {
    enable = true;
    port = 9000;
    fileUploadBaseUrl = "https://files.neet.cloud/irc/";
    host = "irc.neet.dev";
    fileHost = {
      host = "files.neet.cloud";
      path = "/irc";
    };
  };

  services.murmur = {
    enable = true;
    port = 23563;
    domain = "voice.neet.space";
  };

  services.nginx.enable = true;
  services.nginx.virtualHosts."jellyfin.neet.cloud" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://s0.zt.neet.dev:8096";
      proxyWebsockets = true;
    };
  };
  services.nginx.virtualHosts."navidrome.neet.cloud" = {
    enableACME = true;
    forceSSL = true;
    locations."/".proxyPass = "http://s0.zt.neet.dev:4533";
  };

  security.acme.acceptTerms = true;
  security.acme.email = "zuckerberg@neet.dev";
}