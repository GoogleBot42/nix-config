{ config, pkgs, lib, ... }:

let
  cfg = config.de;
in {
  imports = [
    ./kde.nix
    ./xfce.nix
    ./yubikey.nix
    ./chromium.nix
#    ./firefox.nix
    ./audio.nix
#    ./torbrowser.nix
    ./pithos.nix
    ./spotify.nix
    ./vscodium.nix
    ./discord.nix
    ./steam.nix
    ./touchpad.nix
  ];

  options.de = {
    enable = lib.mkEnableOption "enable desktop environment";
  };

  config = lib.mkIf cfg.enable {
    # vulkan
    hardware.opengl.driSupport = true;
    hardware.opengl.driSupport32Bit = true;

    # Applications
    users.users.googlebot.packages = with pkgs; [
      chromium
      keepassxc
      mumble
      tigervnc
      bluez-tools
      vscodium
      element-desktop
      mpv
      nextcloud-client
      signal-desktop
      minecraft
      sauerbraten
      gnome.file-roller
      gparted
      lm_sensors
      libreoffice-fresh
    ];

    # Networking
    networking.networkmanager.enable = true;
    users.users.googlebot.extraGroups = [ "networkmanager" ];

    # Printing
    services.printing.enable = true;

    # Security
    services.gnome.gnome-keyring.enable = true;
    security.pam.services.googlebot.enableGnomeKeyring = true;
  };
}
