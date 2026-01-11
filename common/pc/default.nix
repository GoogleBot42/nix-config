{ config, pkgs, lib, ... }:

let
  cfg = config.de;
in
{
  imports = [
    ./kde.nix
    ./yubikey.nix
    ./chromium.nix
    ./firefox.nix
    ./audio.nix
    ./pithos.nix
    ./vscodium.nix
    ./discord.nix
    ./steam.nix
    ./touchpad.nix
    ./mount-samba.nix
    ./udev.nix
    ./virtualisation.nix
  ];

  options.de = {
    enable = lib.mkEnableOption "enable desktop environment";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      # https://github.com/NixOS/nixpkgs/pull/328086#issuecomment-2235384618
      gparted
    ];

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
      libreoffice-fresh
      thunderbird
      spotify
      arduino
      yt-dlp
      joplin-desktop
      config.inputs.deploy-rs.packages.${config.currentSystem}.deploy-rs
      lxqt.pavucontrol-qt
      deskflow
      file-roller
      android-tools

      # For Nix IDE
      nixpkgs-fmt
      nixd
      nil
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
    services.avahi.nssmdns4 = true;

    # Security
    services.gnome.gnome-keyring.enable = true;
    security.pam.services.googlebot.enableGnomeKeyring = true;

    # Mount personal SMB stores
    services.mount-samba.enable = true;

    # allow building ARM derivations
    boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

    # for luks onlock over tor
    services.tor.enable = true;
    services.tor.client.enable = true;

    # Enable wayland support in various chromium based applications
    environment.sessionVariables.NIXOS_OZONE_WL = "1";

    fonts.packages = with pkgs; [ nerd-fonts.symbols-only ];
  };
}
