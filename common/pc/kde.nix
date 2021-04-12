{ lib, config, pkgs, ... }:

let
  cfg = config.de;
in {
  config = lib.mkIf cfg.enable {
    # kde plasma
    services.xserver = {
      enable = true;
      desktopManager.plasma5.enable = true;
      displayManager.sddm.enable = true;
    };

    # kde apps
    nixpkgs.config.firefox.enablePlasmaBrowserIntegration = true;
    users.users.googlebot.packages = with pkgs; [
      akonadi kmail plasma5Packages.kmail-account-wizard
    ];
  };  
}
