{ config, pkgs, lib, ... }:

{
  imports =[
    ./hardware-configuration.nix
  ];

  # oouao6kfyrirxuuyn6d7nzebyyuyrdnoxunjec2pz25zxqmsptlfgqqd.onion

  networking.hostName = "ponyo";

  firmware.x86_64.enable = true;
  efi.enable = true;

  luks = {
    enable = true;
    device.path = "/dev/disk/by-uuid/4f5cd792-716a-4dbb-9a1d-dd7b37948acc";
  };

  system.autoUpgrade.enable = true;

  services.zerotierone.enable = true;

  security.acme.acceptTerms = true;
  security.acme.email = "zuckerberg@neet.dev";
}