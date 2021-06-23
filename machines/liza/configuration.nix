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

  networking.hostName = "liza";

  networking.interfaces.enp1s0.useDHCP = true;

  services.gitea = {
    enable = true;
    hostname = "git.neet.dev";
    disableRegistration = true;
  };

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

  services.nginx.virtualHosts."radio.neet.space" = {
    enableACME = true;
    forceSSL = true;
    locations."/".root = builtins.fetchTarball {
      url = "https://git.neet.dev/zuckerberg/radio-web/archive/a69e0e27b70694a8fffe8834d7e5f0e67db83dfa.tar.gz";
      sha256 = "076q540my5ssbhwlc8v8vafcddcq7ydxnzagw4qqr1ii6ikfn80w";
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

  security.acme.acceptTerms = true;
  security.acme.email = "zuckerberg@neet.dev";
}
