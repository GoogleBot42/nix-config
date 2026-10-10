{ lib, config, pkgs, ... }:

let
  cfg = config.de;
in
{
  config = lib.mkIf cfg.enable {
    services.displayManager.sddm.enable = true;
    services.displayManager.sddm.wayland.enable = true;
    services.desktopManager.plasma6.enable = true;

    # Plasma Bigscreen is only for media-center machines. It ships a "Plasma
    # Bigscreen" app-launcher entry that swaps the running plasmashell into the
    # TV shell in place, so it must stay off every other desktop.
    services.displayManager.sessionPackages = lib.mkIf config.thisMachine.hasRole."media-center" [
      pkgs.plasma-bigscreen
    ];

    # Bigscreen binaries must be on PATH for autostart services, KCMs, and
    # internal plasmashell launches (settings, input handler, envmanager, etc.)
    environment.systemPackages = lib.mkIf config.thisMachine.hasRole."media-center" [ pkgs.plasma-bigscreen ];

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
