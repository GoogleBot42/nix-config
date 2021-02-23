{ config, pkgs, ... }:

{
  # Audio
  sound.enable = true;
  nixpkgs.config.pulseaudio = true; # enable pulseaudio support for packages
  hardware.pulseaudio = {
    enable = true;
    support32Bit = true;
    package = pkgs.pulseaudioFull; # bt headset support
    extraConfig = "
      load-module module-switch-on-connect
      load-module module-switch-on-connect ignore_virtual=no
    ";
  };
  hardware.bluetooth.enable = true;
  users.users.googlebot.extraGroups = [ "audio" ];  
}
