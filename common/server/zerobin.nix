{ config, pkgs, ... }:

let
  cfg = config.services.zerobin;
in {
  options.services.zerobin = {
    host = lib.mkOption {
      type = lib.types.str;
      example = "example.com";
    };
    port = lib.mkOption {
      type = lib.types.int;
      default = 33422;
    };
  };
  config = lib.mkIf cfg.enable {
    services.zerobin.listenPort = cfg.port;
    services.zerobin.listenAddress = "localhost";

    services.nginx.virtualHosts.${cfg.host} = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://localhost:${toString cfg.port}";
        proxyWebsockets = true;
      };
    };
  };
}
