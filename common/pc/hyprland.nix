{ lib, config, pkgs, ... }:

let
  cfg = config.de;
in
{
  config = lib.mkIf cfg.enable {
    programs.hyprland.enable = true;
    programs.hyprland.withUWSM = true;
    programs.hyprland.xwayland.enable = true;

    xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-hyprland ];

    environment.systemPackages = with pkgs; [
      # Bar
      waybar

      # Launcher
      wofi

      # Notifications
      mako

      # Lock/idle
      hyprlock
      hypridle

      # Wallpaper
      hyprpaper

      # Polkit
      hyprpolkitagent

      # Screenshots
      grim
      slurp

      # Clipboard
      wl-clipboard
      cliphist

      # Color picker
      hyprpicker

      # Brightness (laptop keybinds)
      brightnessctl
    ];
  };
}
