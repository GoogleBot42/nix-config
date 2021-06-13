{ config, pkgs, lib, ... }:

{
  imports =[
    ./hardware-configuration.nix
    ../../common/common.nix
  ];

  # fjhduiepwmuenuev2d2i22py6idc5h2k72ylh3fbrrxr7an6dw6ogfid.onion

  nix.flakes.enable = true;

  bios = {
    enable = true;
    device = "/dev/sda";
  };

  luks = {
    enable = true;
    device.path = "/dev/raid0/raid0lv";
  };

  networking.hostName = "liza";

  networking.interfaces.enp1s0.useDHCP = true;

  security.acme.acceptTerms = true;
  security.acme.email = "zuckerberg@neet.dev";
}
