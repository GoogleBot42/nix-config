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
      appName = cfg.hostname;
      lfs.enable = true;
      # dump.enable = true;
      settings = {
        server = {
          ROOT_URL = "https://${cfg.hostname}/";
          DOMAIN = cfg.hostname;
        };
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
          MAILER_TYPE = "smtp";
          SMTP_ADDR = "mail.neet.dev";
          SMTP_PORT = "465";
          IS_TLS_ENABLED = true;
          USER = "robot@runyan.org";
          FROM = "no-reply@neet.dev";
        };
        actions = {
          ENABLED = true;
        };
        indexer = {
          REPO_INDEXER_ENABLED = true;
        };
      };
      mailerPasswordFile = "/run/agenix/robots-email-pw";
    };
    age.secrets.robots-email-pw = {
      file = ../../secrets/robots-email-pw.age;
      owner = config.services.gitea.user;
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
        proxyPass = "http://localhost:${toString cfg.settings.server.HTTP_PORT}";
      };
    };
  };
}
