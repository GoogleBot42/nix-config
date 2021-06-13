{ config, pkgs, lib, ... }:

{
  imports =[
    ./hardware-configuration.nix
    ../../common/common.nix
  ];

  # 5synsrjgvfzywruomjsfvfwhhlgxqhyofkzeqt2eisyijvjvebnu2xyd.onion

  nix.flakes.enable = true;

  bios = {
    enable = true;
    device = "/dev/sda";
  };

  luks = {
    enable = true;
    device.path = "/dev/disk/by-uuid/2f736fba-8a0c-4fb5-8041-c849fb5e1297";
  };

  services.gitea = {
    enable = true;
    hostname = "git.neet.dev";
  };

  networking.hostName = "liza";

  networking.interfaces.enp1s0.useDHCP = true;

  security.acme.acceptTerms = true;
  security.acme.email = "zuckerberg@neet.dev";
}
