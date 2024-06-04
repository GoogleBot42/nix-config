{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  nixpkgs.config.cudaSupport = true;

  # don't use remote builders
  nix.distributedBuilds = lib.mkForce false;

  # services.howdy.enable = true;

  hardware.openrazer.enable = true;
  hardware.openrazer.users = [ "googlebot" ];
  hardware.openrazer.devicesOffOnScreensaver = false;
  users.users.googlebot.packages = [ pkgs.polychromatic ];

  de.enable = true;
  de.touchpad.enable = true;
}
