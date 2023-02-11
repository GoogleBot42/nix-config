{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # jxx2exuihlls2t6ncs7rvrjh2dssubjmjtclwr2ysvxtr4t7jv55xmqd.onion

  networking.hostName = "router";

  services.zerotierone.enable = true;

  system.autoUpgrade.enable = true;

  networking.useDHCP = lib.mkForce true;
}