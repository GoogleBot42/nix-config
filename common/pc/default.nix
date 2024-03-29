{ config, pkgs, lib, ... }:

let
  cfg = config.de;
in
{
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
    ./mount-samba.nix
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
      element-desktop
      mpv
      nextcloud-client
      signal-desktop
      minecraft
      gparted
      libreoffice-fresh
      thunderbird
      spotifyd
      spotify-qt
      arduino
      yt-dlp
      jellyfin-media-player
      joplin-desktop
      config.inputs.deploy-rs.packages.${config.currentSystem}.deploy-rs
      lxqt.pavucontrol-qt
      barrier

      # For Nix IDE
      nixpkgs-fmt
    ];

    # Networking
    networking.networkmanager.enable = true;
    users.users.googlebot.extraGroups = [ "networkmanager" ];

    # Printing
    services.printing.enable = true;
    services.printing.drivers = with pkgs; [
      gutenprint
    ];
    # Printer discovery
    services.avahi.enable = true;
    services.avahi.nssmdns = true;

    programs.file-roller.enable = true;

    # Security
    services.gnome.gnome-keyring.enable = true;
    security.pam.services.googlebot.enableGnomeKeyring = true;
  };
}
