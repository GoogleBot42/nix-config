{ lib, config, ... }:

let
  cfg = config.services.zerotierone;
in {
  config = lib.mkIf cfg.enable {
    services.zerotierone.joinNetworks = [
      "565799d8f6d654c0"
    ];
    networking.firewall.allowedUDPPorts = [
      9993
    ];
  };
}