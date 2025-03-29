{ lib, config, pkgs, ... }:

let
  cfg = config.de;
in
{
  config = lib.mkIf cfg.enable {
    services.displayManager.sddm.enable = true;
    services.displayManager.sddm.wayland.enable = true;
    services.desktopManager.plasma6.enable = true;

    # kde apps
    users.users.googlebot.packages = with pkgs; [
      # akonadi
      # kmail
      # plasma5Packages.kmail-account-wizard
      kdePackages.kate
    ];
  };
}
