{ lib, config, pkgs, ... }:

let
  cfg = config.services.nginx;
in
{
  options.services.nginx = {
    openFirewall = lib.mkEnableOption "Open firewall ports 80 and 443";
  };

  config = lib.mkIf cfg.enable {
    services.nginx = {
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
    };

    services.nginx.openFirewall = lib.mkDefault true;

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ 80 443 ];
  };
}
