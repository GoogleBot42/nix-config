{ lib, config, pkgs, ... }:

let
  cfg = config.de;
in
{
  config = lib.mkIf cfg.enable {
    services.xserver = {
      enable = true;
      desktopManager = {
        xterm.enable = false;
        xfce.enable = true;
      };
      displayManager.sddm.enable = true;
    };

    # xfce apps
    # TODO for some reason whiskermenu needs to be global for it to work
    environment.systemPackages = with pkgs; [
      xfce.xfce4-whiskermenu-plugin
    ];
  };
}
