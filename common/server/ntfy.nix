{ lib, config, ... }:

let
  cfg = config.services.ntfy-sh;
in
{
  options.services.ntfy-sh = {
    hostname = lib.mkOption {
      type = lib.types.str;
      example = "ntfy.example.com";
    };
  };

  config = lib.mkIf cfg.enable {
    services.ntfy-sh.settings = {
      base-url = "https://${cfg.hostname}";
      listen-http = "127.0.0.1:2586";
      auth-default-access = "deny-all";
      behind-proxy = true;
      enable-login = true;
    };

    # backups
    backup.group."ntfy".paths = [
      "/var/lib/ntfy-sh"
    ];

    services.nginx.enable = true;
    services.nginx.virtualHosts.${cfg.hostname} = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:2586";
        proxyWebsockets = true;
      };
    };
  };
}
