{ lib, config, ... }:

let
  cfg = config.services.gitea;
in {
  options.services.gitea = {
    hostname = lib.mkOption {
      type = lib.types.str;
      example = "example.com";
    };
  };
  config = lib.mkIf cfg.enable {
    services.gitea = {
      domain = cfg.hostname;
      rootUrl = "https://${cfg.hostname}/";
      appName = cfg.hostname;
      ssh.enable = true;
      # lfs.enable = true;
      dump.enable = true;
      cookieSecure = true;
      disableRegistration = true;
      settings = {
        other = {
          SHOW_FOOTER_VERSION = false;
        };
        ui = {
          DEFAULT_THEME = "arc-green";
        };
      };
    };
    services.nginx.enable = true;
    services.nginx.virtualHosts.${cfg.hostname} = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://localhost:${toString cfg.httpPort}";
      };
    };
  };
}