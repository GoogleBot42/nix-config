{ config, pkgs, lib, ... }:

{
  imports =[
    ./hardware-configuration.nix
    ../../common/common.nix
    ../../common/boot/bios.nix
    ../../common/boot/luks.nix
    ../../common/server/nginx.nix
  ];

  # uxzq63kr2uuwutpaqjna2sg4gnk3p65e5bkvedzx5dsxx2mvxhjm7fid.onion

  boot.loader.grub.device = "/dev/vda";
  networking.hostName = "nanachi";
  boot.initrd.luks.devices.enc-pv.device = "/dev/disk/by-uuid/e57ac752-bd99-421f-a3b9-0cfa9608a54e";

  networking.wireless.enable = false;
  networking.useDHCP = false;
  networking.interfaces.ens3.useDHCP = true;

  security.acme.acceptTerms = true;
  security.acme.email = "letsencrypt+5@tar.ninja";

  nix.flakes.enable = true;

  services.nginx.virtualHosts."nanachi.neet.dev" = {
    enableACME = true;
    forceSSL = true;
    root = "/var/www/tmp";
  };
}
