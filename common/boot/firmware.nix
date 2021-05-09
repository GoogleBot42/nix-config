{ lib, config, pkgs, ... }:

with lib;
let
  cfg = config.firmware;
in {
  options.firmware.x86_64 = {
    enable = mkEnableOption "enable x86_64 firmware";
  };

  config = mkIf cfg.firmware.x86_64 {
    hardware.cpu.intel.updateMicrocode = true;
    hardware.cpu.amd.updateMicrocode = true;
  };

  # services.fwupd.enable = true;
}