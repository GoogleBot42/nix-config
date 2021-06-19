{ config, pkgs, lib, ... }:

{
  imports =[
    ./hardware-configuration.nix
    ../../common/common.nix
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
    whitelist = {
      GoogleBot42 = "cae9249c-9e07-450f-8468-60db9950c01d";
      ArcaneMagus = "f367dce9-c255-4fd8-840c-fd772e3f381e";
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

  security.acme.acceptTerms = true;
  security.acme.email = "zuckerberg@neet.dev";
}
