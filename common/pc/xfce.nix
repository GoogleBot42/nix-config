{ lib, config, pkgs, ... }:

let
  cfg = config.de;
in {
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
    users.users.googlebot.packages = with pkgs; [
    ];
  };
}
