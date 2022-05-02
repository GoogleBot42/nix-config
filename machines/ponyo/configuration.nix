{ config, pkgs, lib, mkVpnContainer, ... }:

{
  imports =[
    ./hardware-configuration.nix
  ];

  networking.hostName = "ponyo";

  firmware.x86_64.enable = true;
  bios = {
    enable = true;
    device = "/dev/sda";
  };

  luks = {
    enable = true;
    device.path = "/dev/disk/by-uuid/4cc36be4-dbff-4afe-927d-69bf4637bae2";
  };

  system.autoUpgrade.enable = true;

  services.zerotierone.enable = true;

  services.gitea = {
    enable = true;
    hostname = "git.neet.dev";
    disableRegistration = true;
  };

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

  services.murmur = {
    enable = true;
    port = 23563;
    domain = "voice.neet.space";
  };

  services.drastikbot = {
    enable = true;
    wolframAppIdFile = "/run/agenix/wolframalpha";
  };
  age.secrets.wolframalpha = {
    file = ../../secrets/wolframalpha.age;
    owner = config.services.drastikbot.user;
  };

  # wrap radio in a VPN
  containers.vpn = mkVpnContainer pkgs "/dev/null" {
    services.radio = {
      enable = true;
      host = "radio.neet.space";
    };
  };
  # containers cannot unlock their own secrets right now. unlock it here
  age.secrets."pia-login.conf".file = ../../secrets/pia-login.conf;

  # icecast endpoint + website
  services.nginx.virtualHosts."radio.neet.space" = {
    enableACME = true;
    forceSSL = true;
    locations = {
      "/stream.mp3" = {
        proxyPass = "http://vpn.containers:8001/stream.mp3";
        extraConfig = ''
          add_header Access-Control-Allow-Origin *;
        '';
      };
      "/".root = config.inputs.radio-web;
    };
  };

  services.matrix = {
    enable = true;
    host = "neet.space";
    enable_registration = false;
    element-web = {
      enable = true;
      host = "chat.neet.space";
    };
    jitsi-meet = {
      enable = true;
      host = "meet.neet.space";
    };
    turn = {
      host = "turn.neet.space";
      secret = "a8369a0e96922abf72494bb888c85831b";
    };
  };
  services.postgresql.package = pkgs.postgresql_11;

  services.searx = {
    enable = true;
    environmentFile = "/run/agenix/searx";
    settings = {
      server.port = 43254;
      server.secret_key = "@SEARX_SECRET_KEY@";
      engines = [ {
        name = "wolframalpha";
        shortcut = "wa";
        api_key = "@WOLFRAM_API_KEY@";
        engine = "wolframalpha_api";
      } ];
    };
  };
  services.nginx.virtualHosts."search.neet.space" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://localhost:${toString config.services.searx.settings.server.port}";
    };
  };
  age.secrets.searx.file = ../../secrets/searx.age;

  # iodine DNS-based vpn
  services.iodine.server = {
    enable = true;
    ip = "192.168.99.1";
    domain = "tun.neet.dev";
    passwordFile = "/run/agenix/iodine";
  };
  age.secrets.iodine.file = ../../secrets/iodine.age;
  networking.firewall.allowedUDPPorts = [ 53 ];

  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
  networking.nat.enable = true;
  networking.nat.internalInterfaces = [
    "dns0" # iodine
    "ve-vpn" # vpn container
  ];
  networking.nat.externalInterface = "ens3";

  services.nginx.enable = true;
  services.nginx.virtualHosts."jellyfin.neet.cloud" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://s0.zt.neet.dev:8096";
      proxyWebsockets = true;
    };
  };
  services.nginx.virtualHosts."navidrome.neet.cloud" = {
    enableACME = true;
    forceSSL = true;
    locations."/".proxyPass = "http://s0.zt.neet.dev:4533";
  };

  services.nginx.virtualHosts."tmp.neet.dev" = {
    enableACME = true;
    forceSSL = true;
    root = "/var/www/tmp";
  };

  security.acme.acceptTerms = true;
  security.acme.email = "zuckerberg@neet.dev";
}