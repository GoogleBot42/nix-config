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
      # gparted runs as root via pkexec, which strips the user's environment and
      # GTK config, so the wrapper has to carry the Plasma GTK theme itself
      (gparted.overrideAttrs (old: {
        preFixup = old.preFixup + ''
          gappsWrapperArgs+=(
            --set GTK_THEME Breeze-Dark
            --prefix XDG_DATA_DIRS : "${kdePackages.breeze-gtk}/share"
          )
        '';
      }))
    ];

    # gparted's launcher escalates through pkexec, which needs the setuid wrapper
    security.polkit.enablePkexecWrapper = true;

    # Wi-Fi 6E clients need a pinned regulatory domain: with the world domain
    # the 6 GHz band is disabled, and driver hints alone flip it back and forth
    boot.extraModprobeConfig = "options cfg80211 ieee80211_regdom=US";
    hardware.wirelessRegulatoryDatabase = true;

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
      libreoffice-stable
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

    # Spotify Connect discovery
    networking.firewall.allowedTCPPorts = [ 57621 ];

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
