{ config, pkgs, lib, mkVpnContainer, ... }:

let
  mta-sts-web = {
    enableACME = true;
    forceSSL = true;
    locations."=/.well-known/mta-sts.txt".alias = pkgs.writeText "mta-sts.txt" ''
      version: STSv1
      mode: none
      mx: mail.neet.dev
      max_age: 86400
    '';
  };
in {
  imports =[
    ./hardware-configuration.nix
  ];

  # 5synsrjgvfzywruomjsfvfwhhlgxqhyofkzeqt2eisyijvjvebnu2xyd.onion

  firmware.x86_64.enable = true;
  bios = {
    enable = true;
    device = "/dev/sda";
  };

  luks = {
    enable = true;
    device.path = "/dev/disk/by-uuid/2f736fba-8a0c-4fb5-8041-c849fb5e1297";
  };

  system.autoUpgrade.enable = true;

  networking.hostName = "liza";

  networking.interfaces.enp1s0.useDHCP = true;

  services.gitea = {
    enable = true;
    hostname = "git.neet.dev";
    disableRegistration = true;
  };

  services.peertube = {
    enable = true;
    localDomain = "tube.neet.space";
    listenHttp = 9000;
    listenWeb = 443;
    enableWebHttps = true;
    # dataDirs
    serviceEnvironmentFile = "/run/agenix/peertube-init";
    # settings
    database = {
      createLocally = true;
      passwordFile = "/run/agenix/peertube-db-pw";
    };
    redis = {
      createLocally = true;
      passwordFile = "/run/agenix/peertube-redis-pw";
    };
    smtp = {
      createLocally = false;
      passwordFile = "/run/agenix/peertube-smtp";
    };
  };
  services.nginx.virtualHosts."tube.neet.space" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://localhost:${toString config.services.peertube.listenHttp}";
      proxyWebsockets = true;
    };
  };
  age.secrets.peertube-init.file = ../../secrets/peertube-init.age;
  age.secrets.peertube-db-pw.file = ../../secrets/peertube-db-pw.age;
  age.secrets.peertube-redis-pw.file = ../../secrets/peertube-redis-pw.age;
  age.secrets.peertube-smtp.file = ../../secrets/peertube-smtp.age;
  networking.firewall.allowedTCPPorts = [ 1935 ];

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

  services.minecraft-server = {
    enable = true;
    jvmOpts = "-Xms2048M -Xmx4092M -XX:+UseG1GC -XX:ParallelGCThreads=2 -XX:MinHeapFreeRatio=5 -XX:MaxHeapFreeRatio=10";
    eula = true;
    declarative = true;
    serverProperties = {
      motd = "Welcome :)";
      server-port = 38358;
      white-list = false;
    };
    openFirewall = true;
    package = pkgs.minecraft-server.overrideAttrs (old: {
      version = "1.17";
      src = pkgs.fetchurl {
        url = "https://launcher.mojang.com/v1/objects/0a269b5f2c5b93b1712d0f5dc43b6182b9ab254e/server.jar";
        sha1 = "0a269b5f2c5b93b1712d0f5dc43b6182b9ab254e";
      };
    });
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

  services.drastikbot = {
    enable = true;
    wolframAppIdFile = "/run/agenix/wolframalpha";
  };
  age.secrets.wolframalpha = {
    file = ../../secrets/wolframalpha.age;
    owner = config.services.drastikbot.user;
  };

  # icecast endpoint + website
  services.nginx.virtualHosts."radio.neet.space" = {
    enableACME = true;
    forceSSL = true;
    locations = {
      "/stream.mp3" = {
        proxyPass = "http://172.16.100.2:8001/stream.mp3";
        extraConfig = ''
          add_header Access-Control-Allow-Origin *;
        '';
      };
      "/".root = config.inputs.radio-web;
    };
  };

  services.nginx.virtualHosts."paradigminteractive.agency" = {
    enableACME = true;
    forceSSL = true;
    locations."/".root = builtins.fetchTarball {
      url = "https://git.neet.dev/zuckerberg/paradigminteractive.agency/archive/b91f3ea2884ddd902461a8acb47f20ae04bc28ee.tar.gz";
      sha256 = "1x1fpsd1qr0004hfcxk6j4c4n3wwxykzhnv47gmrdnx5hq1nbzq4";
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

  services.nginx.virtualHosts."tmp.neet.dev" = {
    enableACME = true;
    forceSSL = true;
    root = "/var/www/tmp";
  };

  mailserver = {
    enable = true;
    fqdn = "mail.neet.dev";
    dkimKeyBits = 2048;
    indexDir = "/var/lib/mailindex";
    enableManageSieve = true;
    fullTextSearch.enable = true;
    fullTextSearch.indexAttachments = true;
    fullTextSearch.memoryLimit = 500;
    domains = [
      "neet.space" "neet.dev" "neet.cloud"
      "runyan.org" "runyan.rocks"
      "thunderhex.com" "tar.ninja"
      "bsd.ninja" "bsd.rocks"
      "paradigminteractive.agency"
    ];
    loginAccounts = {
      "jeremy@runyan.org" = {
        hashedPasswordFile = "/run/agenix/email-pw";
        aliases = [
          "@neet.space" "@neet.cloud" "@neet.dev"
          "@runyan.org" "@runyan.rocks"
          "@thunderhex.com" "@tar.ninja"
          "@bsd.ninja" "@bsd.rocks"
          "@paradigminteractive.agency"
        ];
      };
    };
    rejectRecipients = [
      "george@runyan.org"
      "joslyn@runyan.org"
      "damon@runyan.org"
      "jonas@runyan.org"
    ];
    certificateScheme = 3; # use let's encrypt for certs
  };
  age.secrets.email-pw.file = ../../secrets/email-pw.age;
  services.nginx.virtualHosts."mta-sts.runyan.org" = mta-sts-web;
  services.nginx.virtualHosts."mta-sts.runyan.rocks" = mta-sts-web;
  services.nginx.virtualHosts."mta-sts.thunderhex.com" = mta-sts-web;
  services.nginx.virtualHosts."mta-sts.tar.ninja" = mta-sts-web;
  services.nginx.virtualHosts."mta-sts.bsd.ninja" = mta-sts-web;
  services.nginx.virtualHosts."mta-sts.bsd.rocks" = mta-sts-web;

  services.nextcloud = {
    enable = true;
    https = true;
    package = pkgs.nextcloud22;
    hostName = "neet.cloud";
    config.dbtype = "sqlite";
    config.adminuser = "jeremy";
    config.adminpassFile = "/run/agenix/nextcloud-pw";
    autoUpdateApps.enable = true;
  };
  age.secrets.nextcloud-pw = {
    file = ../../secrets/nextcloud-pw.age;
    owner = "nextcloud";
  };
  services.nginx.virtualHosts.${config.services.nextcloud.hostName} = {
    enableACME = true;
    forceSSL = true;
  };

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
  networking.nat.externalInterface = "enp1s0";

  security.acme.acceptTerms = true;
  security.acme.email = "zuckerberg@neet.dev";
}
