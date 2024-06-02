{ config, pkgs, lib, nixos-hardware, ... }:

{
  imports = [
    ./hardware-configuration.nix
    nixos-hardware.nixosModules.framework-13-7040-amd
  ];


  # for luks onlock over tor
  services.tor.enable = true;
  services.tor.client.enable = true;

  # don't use remote builders
  nix.distributedBuilds = lib.mkForce false;

  services.udev.extraRules = ''
    # depthai
    SUBSYSTEM=="usb", ATTRS{idVendor}=="03e7", MODE="0666"

    # Moonlander
    # Rules for Oryx web flashing and live training
    KERNEL=="hidraw*", ATTRS{idVendor}=="16c0", MODE="0664", GROUP="plugdev"
    KERNEL=="hidraw*", ATTRS{idVendor}=="3297", MODE="0664", GROUP="plugdev"
    # Wally Flashing rules for the Moonlander and Planck EZ
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="df11", MODE:="0666", SYMLINK+="stm32_dfu"
  '';
  services.udev.packages = [ pkgs.platformio ];
  users.groups.plugdev = {
    members = [ "googlebot" ];
  };

  # virt-manager
  virtualisation.libvirtd.enable = true;
  programs.dconf.enable = true;
  virtualisation.spiceUSBRedirection.enable = true;
  environment.systemPackages = with pkgs; [ virt-manager ];
  users.users.googlebot.extraGroups = [ "libvirtd" "adbusers" ];

  # allow building ARM derivations
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  services.spotifyd.enable = true;

  virtualisation.podman.enable = true;
  virtualisation.podman.dockerCompat = true;

  virtualisation.appvm.enable = true;
  virtualisation.appvm.user = "googlebot";

  services.mount-samba.enable = true;

  de.enable = true;
  de.touchpad.enable = true;

  networking.firewall.allowedTCPPorts = [
    # barrier
    24800
  ];

  programs.adb.enable = true;

  # thunderbolt
  users.users.googlebot.packages = with pkgs; [
    kdePackages.plasma-thunderbolt
  ];

  services.fwupd.enable = true;

  # fingerprint reader has initially shown to be more of a nuisance than a help
  # it makes sddm log in fail most of the time and take several minutes to finish
  services.fprintd.enable = false;
}
