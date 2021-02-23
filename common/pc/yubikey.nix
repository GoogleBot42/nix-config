{ config, pkgs, ... }:

{
  # yubikey
  services.pcscd.enable = true;
  services.udev.packages = [ pkgs.yubikey-personalization ];  
}
