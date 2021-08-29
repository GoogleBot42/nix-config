{ config, pkgs, lib, ... }:

{
  imports =[
    ./hardware-configuration.nix
  ];

  # 5synsrjgvfzywruomjsfvfwhhlgxqhyofkzeqt2eisyijvjvebnu2xyd.onion

  nix.flakes.enable = true;

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
    serviceEnvironmentFile = "/run/secrets/peertube-init";
    # settings
    database = {
      createLocally = true;
      passwordFile = "/run/secrets/peertube-db-pw";
    };
    redis = {
      createLocally = true;
      passwordFile = "/run/secrets/peertube-redis-pw";
    };
    smtp = {
      createLocally = false;
      passwordFile = "/run/secrets/peertube-smtp";
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

  services.drastikbot.enable = true;

  services.searx = {
    enable = true;
    environmentFile = "/run/secrets/searx";
    settings = {
      server.port = 8080;
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

  services.radio = {
    enable = true;
    host = "radio.neet.space";
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
    ];
    loginAccounts = {
      "jeremy@runyan.org" = {
        hashedPasswordFile = "/run/secrets/email-pw";
        aliases = [
          "@neet.space" "@neet.cloud" "@neet.dev"
          "@runyan.org" "@runyan.rocks"
          "@thunderhex.com" "@tar.ninja"
          "@bsd.ninja" "@bsd.rocks"
        ];
      };
    };
    rejectRecipients = [
      "george@runyan.org"
    ];
    certificateScheme = 3; # use let's encrypt for certs
  };
  age.secrets.email-pw.file = ../../secrets/email-pw.age;

  security.acme.acceptTerms = true;
  security.acme.email = "zuckerberg@neet.dev";
}
