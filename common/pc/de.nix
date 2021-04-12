{ config, pkgs, lib, ... }:

let
  cfg = config.de;
in {
  imports = [
    ./kde.nix
    ./xfce.nix
    ./yubikey.nix
    ./chromium.nix
    ./firefox.nix
    ./audio.nix
    ./torbrowser.nix
    ./pithos.nix
    ./vscodium.nix
    ./discord.nix
    ./steam.nix
    ./touchpad.nix
  ];

  options.de = {
    enable = lib.mkEnableOption "enable desktop environment";
  };

  config = lib.mkIf cfg.enable {
    # allow specific unfree packages
    nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
      "tigervnc" "font-bh-lucidatypewriter" # tigervnc
      "steam" "steam-original" "steam-runtime" # TODO move to steam.nix
      "discord" # TODO move to discord.nix
    ];

    # vulkan
    hardware.opengl.driSupport = true;
    hardware.opengl.driSupport32Bit = true;

    # Applications
    users.users.googlebot.packages = with pkgs; [
      chromium keepassxc mumble tigervnc bluez-tools vscodium element-desktop mpv
    ];

    # Networking
    networking.networkmanager.enable = true;
    users.users.googlebot.extraGroups = [ "networkmanager" ];

    # Printing
    services.printing.enable = true;

    # Security
    services.gnome3.gnome-keyring.enable = true;
    security.pam.services.googlebot.enableGnomeKeyring = true;
  };
}
