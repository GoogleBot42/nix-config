{ lib, config, pkgs, ... }:

let
  cfg = config.de;
in
{
  config = lib.mkIf cfg.enable {
    services.displayManager.sddm.enable = true;
    services.displayManager.sddm.wayland.enable = true;
    services.desktopManager.plasma6.enable = true;

    services.displayManager.sessionPackages = [
      pkgs.plasma-bigscreen
    ];

    # Bigscreen binaries must be on PATH for autostart services, KCMs, and
    # internal plasmashell launches (settings, input handler, envmanager, etc.)
    environment.systemPackages = [ pkgs.plasma-bigscreen ];

    # kde apps
    users.users.googlebot.packages = with pkgs; [
      # akonadi
      # kmail
      # plasma5Packages.kmail-account-wizard
      kdePackages.kate
      kdePackages.kdeconnect-kde
      kdePackages.skanpage
    ];
  };
}
