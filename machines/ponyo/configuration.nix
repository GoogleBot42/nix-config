{ config, pkgs, lib, ... }:

{
  imports =[
    ./hardware-configuration.nix
  ];

  # cfamr6artx75qvt7ho3rrbsc7mkucmv5aawebwflsfuorusayacffryd.onion

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

  security.acme.acceptTerms = true;
  security.acme.email = "zuckerberg@neet.dev";
}