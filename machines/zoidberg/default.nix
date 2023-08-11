{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # services.spotifyd.enable = true;

  # wireless xbox controller support
  hardware.xpadneo.enable = true;

  services.mount-samba.enable = true;

  boot.loader.timeout = lib.mkForce 15;

  de.enable = true;
  services.xserver.desktopManager.kodi.enable = true;

  # virt-manager
  virtualisation.libvirtd.enable = true;
  programs.dconf.enable = true;
  virtualisation.spiceUSBRedirection.enable = true;
  environment.systemPackages = with pkgs; [ virt-manager ];
  users.users.googlebot.extraGroups = [ "libvirtd" ];
}
