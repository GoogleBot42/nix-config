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

  services.zerotier.enable = true;

  containers.jellyfin = {
    ephemeral = true;
    autoStart = true;
    bindMounts = {
      "/var/lib" = {
        hostPath = "/var/lib/";
        isReadOnly = false;
      };
    };
    bindMounts = {
      "/secret" = {
        hostPath = "/secret";
        isReadOnly = true;
      };
    };
    privateNetwork = true;
    hostAddress = "172.16.100.1";
    localAddress = "172.16.100.2";
    config = { config, pkgs, ... }: {
      imports = [ ../../common/common.nix ];
      pia.enable = true;
      services.zerotier.enable = true;
      nixpkgs.pkgs = pkgs;

      services.radarr.enable = true;
      services.bazarr.enable = true;
      services.sonarr.enable = true;
      services.deluge.enable = true;
      services.deluge.web.enable = true;
    };
  };

  networking.nat.enable = true;
  networking.nat.internalInterfaces = [ "ve-*" ];
  networking.nat.externalInterface = "ens3";

  security.acme.acceptTerms = true;
  security.acme.email = "letsencrypt+5@tar.ninja";
}
