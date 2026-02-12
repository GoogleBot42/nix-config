{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # system.autoUpgrade.enable = true;

  # p2p mesh network
  services.tailscale.exitNode = true;

  services.iperf3.enable = true;

  # email server
  mailserver.enable = true;

  # nextcloud
  services.nextcloud.enable = true;

  # git
  services.gitea = {
    enable = true;
    hostname = "git.neet.dev";
  };

  # IRC
  services.thelounge = {
    enable = true;
    port = 9000;
    fileUploadBaseUrl = "https://files.neet.cloud/irc/";
    host = "irc.neet.dev";
    fileHost = {
      host = "files.neet.cloud";
      path = "/irc";
    };
  };

  # mumble
  services.murmur = {
    enable = true;
    port = 23563;
    domain = "voice.neet.space";
  };

  # IRC bot
  services.drastikbot = {
    enable = true;
    wolframAppIdFile = "/run/agenix/wolframalpha";
  };
  age.secrets.wolframalpha = {
    file = ../../secrets/wolframalpha.age;
    owner = config.services.drastikbot.user;
  };
  backup.group."dailybot".paths = [
    config.services.drastikbot.dataDir
  ];

  # matrix home server
  services.matrix = {
    enable = true;
    host = "neet.space";
    enable_registration = false;
    element-web = {
      enable = true;
      host = "chat.neet.space";
    };
    jitsi-meet = {
      enable = false; # disabled until vulnerable libolm dependency is removed/fixed
      host = "meet.neet.space";
    };
    turn = {
      host = "turn.neet.space";
      secret = "a8369a0e96922abf72494bb888c85831b";
    };
  };
  # pin postgresql for matrix (will need to migrate eventually)
  services.postgresql.package = pkgs.postgresql_15;

  # proxied web services
  services.nginx.enable = true;
  services.nginx.virtualHosts."navidrome.neet.cloud" = {
    enableACME = true;
    forceSSL = true;
    locations."/".proxyPass = "http://s0.koi-bebop.ts.net:4533";
  };

  # TODO replace with a proper file hosting service
  services.nginx.virtualHosts."tmp.neet.dev" = {
    enableACME = true;
    forceSSL = true;
    root = "/var/www/tmp";
  };

  # redirect neet.cloud to nextcloud instance on runyan.org
  services.nginx.virtualHosts."neet.cloud" = {
    enableACME = true;
    forceSSL = true;
    extraConfig = ''
      return 302 https://runyan.org$request_uri;
    '';
  };

  # owncast live streaming
  services.owncast.enable = true;
  services.owncast.hostname = "live.neet.dev";

  # librechat
  services.librechat-container.enable = true;
  services.librechat-container.host = "chat.neet.dev";
}
