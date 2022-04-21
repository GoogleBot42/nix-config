{ config, pkgs, lib, ... }:

{
  imports =[
    ./hardware-configuration.nix
  ];

  # un23pkwc3ij7pugl4uiwvdrjjw7xghxbkzppgn3siubqggchbosi6cyd.onion

  networking.hostName = "ponyo";

  firmware.x86_64.enable = true;
  efi.enable = true;
  boot.loader.grub.efiInstallAsRemovable = true;

  luks = {
    enable = true;
    device.path = "/dev/disk/by-uuid/84eaca59-6b03-47b1-9296-9d4736bcf0e0";
  };

  system.autoUpgrade.enable = true;

  services.zerotierone.enable = true;

  security.acme.acceptTerms = true;
  security.acme.email = "zuckerberg@neet.dev";
}