{ config, pkgs, lib, ... }:

{
  imports =[
    ./hardware-configuration.nix
  ];

  # colcxrqbxk4hzck3bhymmed7ak6juv22eve3yur2bpxk645dzsxit3yd.onion

  networking.hostName = "ponyo";

  firmware.x86_64.enable = true;
  bios = {
    enable = true;
    device = "/dev/sda";
  };

  luks = {
    enable = true;
    device.path = "/dev/disk/by-uuid/3492819c-2e5a-44b2-a16c-1e373e8d5881";
  };

  system.autoUpgrade.enable = true;

  services.zerotierone.enable = true;

  networking.interfaces.enp0s5.useDHCP = true;

  security.acme.acceptTerms = true;
  security.acme.email = "zuckerberg@neet.dev";
}