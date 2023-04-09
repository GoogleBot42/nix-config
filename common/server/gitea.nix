{ lib, pkgs, config, ... }:

let
  cfg = config.services.gitea;
in
{
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
      # lfs.enable = true;
      # dump.enable = true;
      settings = {
        other = {
          SHOW_FOOTER_VERSION = false;
        };
        ui = {
          DEFAULT_THEME = "arc-green";
        };
        service = {
          DISABLE_REGISTRATION = true;
        };
        session = {
          COOKIE_SECURE = true;
        };
        mailer = {
          ENABLED = true;
          MAILER_TYPE = "sendmail";
          FROM = "do-not-reply@neet.dev";
          SENDMAIL_PATH = "/run/wrappers/bin/sendmail";
          SENDMAIL_ARGS = "--";
        };
      };
    };

    # backups
    backup.group."gitea".paths = [
      config.services.gitea.stateDir
    ];

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
