{ config, ... }:

{
  imports = [
    ../../common/common.nix
  ];

  nix.flakes.enable = true;

  networking.interfaces.eth0.useDHCP = true;

  hardware.deviceTree.enable = true;
  hardware.deviceTree.overlays = [
    ./sopine-baseboard-ethernet.dtbo # fix pine64 clusterboard ethernet
  ];
}