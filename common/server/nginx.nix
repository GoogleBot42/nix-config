{ lib, config, pkgs, ... }:

let
  cfg = config.services.nginx;
in {
  config = lib.mkIf cfg.enable {
    services.nginx = {
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
    };

    networking.firewall.allowedTCPPorts = [ 80 443 ];
  };
}