{ config, ... }:

{
  services.thelounge = {
    enable = true;
    port = 9000;
    private = true;
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
        baseUrl = "https://files.neet.cloud/irc/";
      };
      transports = [ "websocket" "polling" ];
      leaveMessage = "leaving";
      messageStorage = [ "sqlite" "text" ];
    };
  };

  # the lounge client
  services.nginx.virtualHosts."irc.neet.dev" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://localhost:${toString config.services.thelounge.port}";
      proxyWebsockets = true;
    };
  };

  # the lounge files
  services.nginx.virtualHosts."files.neet.cloud" = {
    enableACME = true;
    forceSSL = true;
    locations."/irc" = {
      proxyPass = "http://localhost:${toString config.services.thelounge.port}/uploads";
    };
  };
}
