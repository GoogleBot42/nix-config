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

    # the lounge client
    services.nginx.virtualHosts.${cfg.host} = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://localhost:${toString config.services.thelounge.port}";
        proxyWebsockets = true;
      };
    };

    # the lounge files
    services.nginx.virtualHosts.${cfg.fileHost.host} = {
      enableACME = true;
      forceSSL = true;
      locations.${cfg.fileHost.path} = {
        proxyPass = "http://localhost:${toString config.services.thelounge.port}/uploads";
      };
    };
  };
}
