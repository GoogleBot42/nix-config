{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./router.nix
  ];

  # https://dataswamp.org/~solene/2022-08-03-nixos-with-live-usb-router.html
  # https://github.com/mdlayher/homelab/blob/391cfc0de06434e4dee0abe2bec7a2f0637345ac/nixos/routnerr-2/configuration.nix
  # https://github.com/skogsbrus/os/blob/master/sys/router.nix
  # http://trac.gateworks.com/wiki/wireless/wifi 

  networking.hostName = "router";

  system.autoUpgrade.enable = true;

  services.tailscale.exitNode = true;

  router.enable = true;
  router.privateSubnet = "192.168.3";

  services.iperf3.enable = true;

  # networking.useDHCP = lib.mkForce true;

  # TODO
  # networking.usePredictableInterfaceNames = true;

  powerManagement.cpuFreqGovernor = "ondemand";


  services.irqbalance.enable = true;

  #   services.miniupnpd = {
  #     enable = true;
  #     externalInterface = "eth0";
  #     internalIPs = [ "br0" ];
  # };
}