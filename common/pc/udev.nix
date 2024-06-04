{ config, lib, pkgs, ... }:

let
  cfg = config.de;
in
{
  config = lib.mkIf cfg.enable {
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
  };
}
