{ config, pkgs, ... }:

{
  services.xserver = {
    enable = true;
    desktopManager = {
      xterm.enable = false;
      xfce.enable = true;
    };
    displayManager.sddm.enable = true;
  };

  # xfce apps
  users.users.googlebot.packages = with pkgs; [
  ];  
}
