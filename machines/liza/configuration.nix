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
    ];
    loginAccounts = {
      "jeremy@runyan.org" = {
        hashedPasswordFile = "/run/agenix/email-pw";
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
      "joslyn@runyan.org"
      "damon@runyan.org"
      "jonas@runyan.org"
    ];
    certificateScheme = 3; # use let's encrypt for certs
  };
  age.secrets.email-pw.file = ../../secrets/email-pw.age;

  # relay sent mail through mailgun
  # https://www.howtoforge.com/community/threads/different-smtp-relays-for-different-domains-in-postfix.82711/#post-392620
  services.postfix.config = {
    smtp_sasl_auth_enable = "yes";
    smtp_sasl_security_options = "noanonymous";
    smtp_sasl_password_maps = "hash:/var/lib/postfix/conf/sasl_relay_passwd";
    smtp_use_tls = "yes";
    sender_dependent_relayhost_maps = "hash:/var/lib/postfix/conf/sender_relay";
    smtp_sender_dependent_authentication = "yes";
  };
  services.postfix.mapFiles.sender_relay = let
    relayHost = "[smtp.mailgun.org]:587";
  in pkgs.writeText "sender_relay" ''
    @neet.space ${relayHost}
    @neet.cloud ${relayHost}
    @neet.dev ${relayHost}
    @runyan.org ${relayHost}
    @runyan.rocks ${relayHost}
    @thunderhex.com ${relayHost}
    @tar.ninja ${relayHost}
    @bsd.ninja ${relayHost}
    @bsd.rocks ${relayHost}
  '';
  services.postfix.mapFiles.sasl_relay_passwd = "/run/agenix/sasl_relay_passwd";
  age.secrets.sasl_relay_passwd.file = ../../secrets/sasl_relay_passwd.age;

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
