{ lib, config, pkgs, ... }:

let
  cfg = config.de;
in
{
  config = lib.mkIf cfg.enable {
    programs.steam.enable = true;
    hardware.steam-hardware.enable = true; # steam controller

    # Login DE Option: Steam Gamescope (Steam Deck-like session)
    programs.gamescope = {
      enable = true;
    };
    programs.steam.gamescopeSession = {
      enable = true;
      args = [
        "--hdr-enabled"
        "--hdr-itm-enabled"
        "--adaptive-sync"
      ];
      steamArgs = [
        "-steamos3"
        "-gamepadui"
        "-pipewire-dmabuf"
      ];
      env = {
        STEAM_ENABLE_VOLUME_HANDLER = "1";
        STEAM_DISABLE_AUDIO_DEVICE_SWITCHING = "1";
      };
    };
    environment.systemPackages = [ pkgs.gamescope-wsi ];

    users.users.googlebot.packages = [
      pkgs.steam
    ];
  };
}
