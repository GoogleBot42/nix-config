{ config, pkgs, ... }:

{
  hardware.cpu.intel.updateMicrocode = true;

  # services.fwupd.enable = true;
}