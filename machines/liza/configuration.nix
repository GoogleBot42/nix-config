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

  services.searx.enable = true;
  services.searx.environmentFile = "/run/secrets/searx";
  services.searx.settings.server.port = 8080;
  services.searx.settings.server.secret_key = "@SEARX_SECRET_KEY@";
  services.nginx.virtualHosts."search.neet.space" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://localhost:${toString config.services.searx.settings.server.port}";
    };
  };
  age.secrets.searx.file = ../../secrets/searx.age;

  security.acme.acceptTerms = true;
  security.acme.email = "zuckerberg@neet.dev";
}
