{ config, pkgs, lib, ... }:


let
  cfg = config.mailserver;
in {
  config = lib.mkIf cfg.enable {
    mailserver = {
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

    # sendmail to use xxx@domain instead of xxx@mail.domain
    services.postfix.origin = "$mydomain";

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
  };
}