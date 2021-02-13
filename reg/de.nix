{ config, pkgs, lib, ... }:

{
  # General
  imports = [
    ./kde.nix
    ./xfce.nix
    ./yubikey.nix
    ./chromium.nix
    ./audio.nix
    ./torbrowser.nix
  ];

  # allow specific unfree packages
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "tigervnc" "font-bh-lucidatypewriter" # tigervnc
  ];

  # Applications
  users.users.googlebot.packages = with pkgs; [
    firefox chromium keepassxc mumble tigervnc bluez-tools vscodium
  ];

  # Networking
  networking.networkmanager.enable = true;
  users.users.googlebot.extraGroups = [ "networkmanager" ];

  # Printing
  services.printing.enable = true;

  # Security
  services.gnome3.gnome-keyring.enable = true;
  security.pam.services.googlebot.enableGnomeKeyring = true;
}
