{ lib, config, ... }:

with lib;

let
  cfg = config.services.owncast;
in {
  options.services.owncast = {
    hostname = lib.mkOption {
      type = types.str;
      example = "example.com";
    };
  };

  config = mkIf cfg.enable {
    services.owncast.listen = "127.0.0.1";
    services.owncast.port = 62419; # random port

    networking.firewall.allowedTCPPorts = [ cfg.rtmp-port ];

    services.nginx.enable = true;
    services.nginx.virtualHosts.${cfg.hostname} = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://localhost:${toString cfg.port}";
        proxyWebsockets = true;
      };
    };
  };
}