{ config, lib, pkgs, ... }:

let
  cfg = config.services.unifi;
in
{
  options.services.unifi = {
    # Open select Unifi ports instead of using openFirewall to avoid opening access to unifi's control panel
    openMinimalFirewall = lib.mkEnableOption "Open bare minimum firewall ports";
  };

  config = lib.mkIf cfg.enable {
    services.unifi.unifiPackage = pkgs.unifi8;

    networking.firewall = lib.mkIf cfg.openMinimalFirewall {
      allowedUDPPorts = [
        3478 # STUN
        10001 # used for device discovery.
      ];
      allowedTCPPorts = [
        8080 # Used for device and application communication.
      ];
    };
  };
}
