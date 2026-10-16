{ lib, config, pkgs, ... }:

let
  cfg = config.services.thelounge;
in
{
  options.services.thelounge = {
    fileUploadBaseUrl = lib.mkOption {
      type = lib.types.str;
    };
    host = lib.mkOption {
      type = lib.types.str;
      example = "example.com";
    };
    fileHost = {
      host = lib.mkOption {
        type = lib.types.str;
      };
      path = lib.mkOption {
        type = lib.types.str;
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.thelounge = {
      # thelounge 4.5 bundles got 11, whose retry path throws an uncaught
      # exception on Node >= 24.20 whenever a request fails, taking the whole
      # process down (the GitHub changelog fetch at startup is enough). got 11
      # is unmaintained, so run on the Node 22 LTS line, which lacks the
      # triggering http change: https://github.com/sindresorhus/got/issues/2469
      # The bin/ wrapper execs the npm hooks' nodejs, not the package's, so
      # both must be overridden or the service still runs on Node 24.
      package = pkgs.thelounge.override {
        nodejs-slim = pkgs.nodejs-slim_22;
        npmHooks = pkgs.npmHooks.override { nodejs = pkgs.nodejs-slim_22; };
      };
      public = false;
      extraConfig = {
        reverseProxy = true;
        maxHistory = -1;
        https.enable = false;
        #      theme = "thelounge-theme-solarized";
        prefetch = false;
        prefetchStorage = false;
        fileUpload = {
          enable = true;
          maxFileSize = -1;
          baseUrl = cfg.fileUploadBaseUrl;
        };
        transports = [ "websocket" "polling" ];
        leaveMessage = "leaving";
        messageStorage = [ "sqlite" "text" ];
      };
    };

    backup.group."thelounge".paths = [
      "/var/lib/thelounge/"
    ];

    # The state directory holds secrets (VAPID keys, password hashes) that
    # thelounge writes with the unit's umask; keep them owner-only.
    systemd.services.thelounge.serviceConfig = {
      # Upstream's unit never restarts: a single crash leaves IRC down until
      # someone notices.
      Restart = "on-failure";
      RestartSec = "10s";
      UMask = "0077";
      StateDirectoryMode = "0750";
    };
    systemd.tmpfiles.rules = [
      "z /var/lib/thelounge/vapid.json 0600 thelounge thelounge -"
      "z /var/lib/thelounge/users/*.json 0600 thelounge thelounge -"
    ];

    # the lounge client
    services.nginx.virtualHosts.${cfg.host} = {
      enableACME = lib.mkDefault true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://localhost:${toString config.services.thelounge.port}";
        proxyWebsockets = true;
      };
    };

    # the lounge files
    services.nginx.virtualHosts.${cfg.fileHost.host} = {
      enableACME = lib.mkDefault true;
      forceSSL = true;
      locations.${cfg.fileHost.path} = {
        proxyPass = "http://localhost:${toString config.services.thelounge.port}/uploads";
      };
    };
  };
}
