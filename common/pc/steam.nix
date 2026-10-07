{ lib, config, pkgs, ... }:

let
  cfg = config.de;
in
{
  config = lib.mkIf cfg.enable {
    programs.steam.enable = true;
    hardware.steam-hardware.enable = true; # steam controller

    # Remote Play hosts (Steam Link, Steam Frame over LAN or its wireless
    # adapter) must accept discovery and stream traffic on every interface
    programs.steam.remotePlay.openFirewall = true;

    # The Steam Frame wireless adapter joins the headset's 6 GHz hotspot as a
    # client. NetworkManager randomises the MAC before every scan by taking the
    # interface down and up, and each flip resets this adapter's regulatory
    # state so wpa_supplicant sees the 6 GHz channel as disabled and never joins.
    networking.networkmanager.settings."device-steam-frame-adapter" = {
      match-device = "driver:rtw89_8852cu";
      "wifi.scan-rand-mac-address" = "no";
    };

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
      config.programs.steam.package
    ];
  };
}
