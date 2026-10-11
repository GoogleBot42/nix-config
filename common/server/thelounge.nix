{ lib, config, ... }:

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
