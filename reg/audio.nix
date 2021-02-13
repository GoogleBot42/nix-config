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
    ";
  };
  hardware.bluetooth.enable = true;
  users.users.googlebot.extraGroups = [ "audio" ];  
}
