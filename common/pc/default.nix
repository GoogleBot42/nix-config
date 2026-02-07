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
      logseq

      # For Nix IDE
      nixpkgs-fmt
      nixd
      nil

      godot-mono
    ];

    # Networking
    networking.networkmanager.enable = true;

    # Printing
    services.printing.enable = true;
    services.printing.drivers = with pkgs; [
      gutenprint
    ];

    # Scanning
    hardware.sane.enable = true;
    hardware.sane.extraBackends = with pkgs; [
      # Enable support for "driverless" scanners
      # Check for support here: https://mfi.apple.com/account/airprint-search
      sane-airscan
    ];

    # Printer/Scanner discovery
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

    # SSH Ask pass
    programs.ssh.enableAskPassword = true;
    programs.ssh.askPassword = "${pkgs.kdePackages.ksshaskpass}/bin/ksshaskpass";

    users.users.googlebot.extraGroups = [
      # Networking
      "networkmanager"
      # Scanning
      "scanner"
      "lp"
    ];
  };
}
