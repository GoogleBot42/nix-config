{ config, pkgs, lib, ... }:

{
  imports =[
    ./hardware-configuration.nix
    ../common/common.nix
    ../common/luks.nix
#   ../common/server/nsd.nix
    ../common/server/thelounge.nix
    ../common/server/mumble.nix
    ../common/server/gitlab.nix
    ../common/server/video-stream.nix
    ../common/server/hydra.nix
  ];

  # Use the GRUB 2 boot loader.
  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.device = "/dev/sda";

  networking.hostName = "neetdev";
  networking.wireless.enable = false;

  networking.useDHCP = true; # just in case... (todo ensure false doesn't fuck up initrd)
  networking.interfaces.eno1.useDHCP = true;

  security.acme.acceptTerms = true;
  security.acme.email = "letsencrypt+5@tar.ninja";
  security.acme.certs = {
    "pages.neet.dev" = {
      group = "nginx";
      domain = "*.pages.neet.dev";
      dnsProvider = "digitalocean";
      credentialsFile = "/var/lib/secrets/certs.secret";
    };
  };

  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
  };

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [ 80 443 ];
  networking.firewall.allowedUDPPorts = [ 80 443 ];

  # LUKS
  boot.initrd.luks.devices.enc-pv.device = "/dev/disk/by-uuid/06f6b0bf-fe79-4b89-a549-b464c2b162a1";

  system.stateVersion = "20.09";
}

