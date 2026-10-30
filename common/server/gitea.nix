{ lib, config, ... }:

let
  cfg = config.services.gitea;
  vhostTailscaleAuth = config.services.nginx.virtualHosts.${cfg.hostname}.tailscaleAuth;
  normalizeTag = tag: if lib.hasPrefix "tag:" tag then tag else "tag:${tag}";
in
{
  options.services.gitea = {
    hostname = lib.mkOption {
      type = lib.types.str;
      example = "example.com";
    };

    tailscaleTagUsers = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = { claude = "agent"; };
      description = ''
        Tailscale ACL tags mapped to the Gitea user that nodes carrying the
        tag are signed in as, with no password or token. nginx-auth reports
        the caller's tags and nginx passes the matching user to Gitea in the
        reverse-proxy auth header. The users must already exist.
      '';
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
          # Reverse-proxy auth trusts the user header from any client that can
          # connect, so only nginx on this host may reach Gitea.
          HTTP_ADDR = "127.0.0.1";
        };
        other = {
          SHOW_FOOTER_VERSION = false;
        };
        ui = {
          DEFAULT_THEME = "gitea-dark";
        };
        service = {
          DISABLE_REGISTRATION = true;
          ENABLE_NOTIFY_MAIL = true;
          ENABLE_REVERSE_PROXY_AUTHENTICATION = cfg.tailscaleTagUsers != { };
          ENABLE_REVERSE_PROXY_AUTHENTICATION_API = cfg.tailscaleTagUsers != { };
          ENABLE_REVERSE_PROXY_AUTO_REGISTRATION = false;
        };
        security.REVERSE_PROXY_AUTHENTICATION_USER = "X-WEBAUTH-USER";
        session = {
          COOKIE_SECURE = true;
          PROVIDER = "db";
          SESSION_LIFE_TIME = 259200; # 3 days
          GC_INTERVAL_TIME = 259200; # 3 days
        };
        mailer = {
          ENABLED = true;
          PROTOCOL = "smtps";
          SMTP_ADDR = "mail.neet.dev";
          SMTP_PORT = 465;
          USER = "robot@runyan.org";
          FROM = "no-reply@neet.dev";
        };
        actions = {
          ENABLED = true;
          # Match the longest workflow and runner timeout.
          ENDLESS_TASK_TIMEOUT = "6h";
        };
        webhook = {
          ALLOWED_HOST_LIST = "external,hooks.fry.neet.dev";
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

    # git-over-ssh sessions are forced-command gitea serv calls, not real logins
    ntfy-alerts.ignoredSshUsers = [ config.services.gitea.user ];

    services.nginx.enable = true;
    services.nginx.virtualHosts.${cfg.hostname} = {
      enableACME = lib.mkDefault true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString cfg.settings.server.HTTP_PORT}";
        # Always set, so a client-supplied header never reaches Gitea; an
        # empty value drops the header.
        extraConfig = lib.mkIf (cfg.tailscaleTagUsers != { }) ''
          proxy_set_header X-WEBAUTH-USER $gitea_tailscale_user;
        '';
      };
      tailscaleAuth = lib.mkIf (cfg.tailscaleTagUsers != { }) {
        enable = true;
        allowedTags = lib.mkDefault (config.services.nginx.tailscaleAuth.defaultAllowedTags ++ lib.attrNames cfg.tailscaleTagUsers);
      };
    };
    services.nginx.appendHttpConfig = lib.mkIf (cfg.tailscaleTagUsers != { }) ''
      map $tailscale_auth_tags $gitea_tailscale_user {
        default "";
        ${lib.concatStrings (lib.mapAttrsToList (tag: user: ''
          "~(^|,)${normalizeTag tag}(,|$)" "${user}";
        '') cfg.tailscaleTagUsers)}
      }
    '';

    assertions = [{
      assertion = cfg.tailscaleTagUsers == { } || lib.all (tag: lib.elem (normalizeTag tag) (map normalizeTag vhostTailscaleAuth.allowedTags)) (lib.attrNames cfg.tailscaleTagUsers);
      message = "services.gitea.tailscaleTagUsers tags must be in the ${cfg.hostname} vhost's tailscaleAuth.allowedTags.";
    }];
  };
}
