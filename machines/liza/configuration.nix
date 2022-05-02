{ config, pkgs, lib, mkVpnContainer, ... }:

{
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

  security.acme.acceptTerms = true;
  security.acme.email = "zuckerberg@neet.dev";
}
