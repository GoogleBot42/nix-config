{ config, pkgs, lib, ... }:

let
  cfg = config.services.searx;
in
{
  config = lib.mkIf cfg.enable {
    services.searx = {
      environmentFile = "/run/agenix/searx";
      settings = {
        server.port = 43254;
        server.secret_key = "@SEARX_SECRET_KEY@";
        engines = [{
          name = "wolframalpha";
          shortcut = "wa";
          api_key = "@WOLFRAM_API_KEY@";
          engine = "wolframalpha_api";
        }];
      };
    };
    services.nginx.virtualHosts."search.neet.space" = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://localhost:${toString config.services.searx.settings.server.port}";
      };
    };
    age.secrets.searx.file = ../../secrets/searx.age;
  };
}
