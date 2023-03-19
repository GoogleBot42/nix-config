{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "ray";

  # for luks onlock over tor
  services.tor.enable = true;
  services.tor.client.enable = true;

  # services.howdy.enable = true;

  hardware.openrazer.enable = true;
  hardware.openrazer.users = [ "googlebot" ];
  hardware.openrazer.devicesOffOnScreensaver = false;
  users.users.googlebot.packages = [ pkgs.polychromatic ];

  # depthai
  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ATTRS{idVendor}=="03e7", MODE="0666"
  '';

  # virt-manager
  virtualisation.libvirtd.enable = true;
  programs.dconf.enable = true;
  virtualisation.spiceUSBRedirection.enable = true;
  environment.systemPackages = with pkgs; [ virt-manager ];
  users.users.googlebot.extraGroups = [ "libvirtd" ];

  # allow building ARM derivations
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  services.spotifyd.enable = true;

  virtualisation.docker.enable = true;

  services.mount-samba.enable = true;

  de.enable = true;
  de.touchpad.enable = true;
}
