{ config, pkgs, lib, ... }:

with builtins;

let
  cfg = config.mailserver;
  tailnetDomain = config.services.tailscale.tailnetDomain;
  webmailHostname = "webmail.kif.neet.dev";
  autoconfigDomains = [
    "neet.dev"
    "runyan.org"
  ];
  autoconfigXml = pkgs.writeText "mail-autoconfig.xml" ''
    <?xml version="1.0" encoding="UTF-8"?>
    <clientConfig version="1.1">
      <emailProvider id="neet.dev">
        <domain>neet.dev</domain>
        <domain>runyan.org</domain>
        <displayName>Neet Mail</displayName>
        <displayShortName>Neet</displayShortName>
        <incomingServer type="imap">
          <hostname>mail.neet.dev</hostname>
          <port>993</port>
          <socketType>SSL</socketType>
          <authentication>password-cleartext</authentication>
          <username>%EMAILADDRESS%</username>
        </incomingServer>
        <outgoingServer type="smtp">
          <hostname>mail.neet.dev</hostname>
          <port>587</port>
          <socketType>STARTTLS</socketType>
          <authentication>password-cleartext</authentication>
          <username>%EMAILADDRESS%</username>
        </outgoingServer>
      </emailProvider>
    </clientConfig>
  '';
  domains = [
    "neet.space"
    "neet.dev"
    "neet.cloud"
    "runyan.org"
    "runyan.rocks"
    "thunderhex.com"
    "tar.ninja"
    "bsd.ninja"
    "bsd.rocks"
  ];
in
{
  config = lib.mkIf cfg.enable {
    # The mail stack needs a recursive, DNSSEC-validating resolver of its own:
    # postfix only engages DANE when the resolver sets the AD bit, and the DNS
    # blocklists (Spamhaus, URIBL, DNSWL) refuse queries that arrive from
    # public resolvers such as the tailnet's Cloudflare upstream, which makes
    # rspamd disable them. So this host recurses from its own address with
    # unbound instead of the resolved stub. MagicDNS names stay reachable
    # through a forward zone to tailscaled's resolver, and tailscale is told
    # not to take over the system resolver.
    services.resolved.enable = false;
    services.unbound = {
      enable = true;
      settings = {
        server = {
          qname-minimisation = true;
          prefetch = true;
          # The tailnet zone is served by tailscaled and is not signed.
          domain-insecure = [ tailnetDomain ];
          private-domain = [ tailnetDomain ];
        };
        forward-zone = [{
          name = tailnetDomain;
          forward-addr = [ "100.100.100.100" ];
        }];
      };
    };
    networking.nameservers = lib.mkForce [ "127.0.0.1" ];
    services.tailscale.extraSetFlags = [ "--accept-dns=false" ];

    mailserver = {
      fqdn = "mail.neet.dev";
      dkim.defaults.keyLength = 2048;
      indexDir = "/var/lib/mailindex";
      listeners.manageSieve.enable = true;
      fullTextSearch.enable = true;
      fullTextSearch.memoryLimit = 500;
      inherit domains;
      accounts = {
        "jeremy@runyan.org" = {
          hashedPasswordFile = "/run/agenix/hashed-email-pw";
          # catchall for all domains
          aliases = map (domain: "@${domain}") domains;
        };
        "cris@runyan.org" = {
          hashedPasswordFile = "/run/agenix/cris-hashed-email-pw";
          aliases = [ "chris@runyan.org" ];
        };
        "robot@runyan.org" = {
          aliases = [
            "no-reply@neet.dev"
            "robot@neet.dev"
          ];
          sendOnly = true;
          hashedPasswordFile = "/run/agenix/hashed-robots-email-pw";
        };
        "agent@neet.dev" = {
          hashedPasswordFile = "/run/agenix/hashed-agent-email-pw";
          quota = "1G";
        };
      };
      rejectRecipients = [
        "george@runyan.org"
        "joslyn@runyan.org"
        "damon@runyan.org"
        "jonas@runyan.org"
        "simon@neet.dev"
        "ellen@runyan.org"
      ];
      forwards = {
        "amazon@runyan.org" = [
          "jeremy@runyan.org"
          "cris@runyan.org"
        ];
      };
      x509.useACMEHost = config.mailserver.fqdn; # use let's encrypt for certs
      stateVersion = 5;
    };
    age.secrets.hashed-email-pw.file = ../../secrets/hashed-email-pw.age;
    age.secrets.cris-hashed-email-pw.file = ../../secrets/cris-hashed-email-pw.age;
    age.secrets.hashed-robots-email-pw.file = ../../secrets/hashed-robots-email-pw.age;
    age.secrets.hashed-agent-email-pw.file = ../../secrets/hashed-agent-email-pw.age;

    # Get let's encrypt cert
    services.nginx = {
      enable = true;
      virtualHosts = {
        "${config.mailserver.fqdn}" = {
          forceSSL = true;
          enableACME = true;
          locations."/".return = "301 https://${webmailHostname}$request_uri";
        };
        ${webmailHostname} = {
          tailscaleOnly = true;
          useACMEHost = "kif.neet.dev";
        };
      } // lib.genAttrs (map (domain: "autoconfig.${domain}") autoconfigDomains) (_: {
        forceSSL = true;
        enableACME = true;
        locations."= /mail/config-v1.1.xml" = {
          alias = autoconfigXml;
          extraConfig = ''
            default_type application/xml;
          '';
        };
      });
    };

    # sendmail to use xxx@domain instead of xxx@mail.domain
    services.postfix.settings.main.myorigin = "$mydomain";

    # relay sent mail through mailgun
    # https://www.howtoforge.com/community/threads/different-smtp-relays-for-different-domains-in-postfix.82711/#post-392620
    services.postfix.settings.main = {
      smtp_sasl_auth_enable = "yes";
      smtp_sasl_security_options = "noanonymous";
      smtp_sasl_password_maps = "hash:/var/lib/postfix/conf/sasl_relay_passwd";
      smtp_use_tls = "yes";
      sender_dependent_relayhost_maps = "hash:/var/lib/postfix/conf/sender_relay";
      smtp_sender_dependent_authentication = "yes";
    };
    services.postfix.mapFiles.sender_relay =
      let
        relayHost = "[smtp.mailgun.org]:587";
      in
      pkgs.writeText "sender_relay"
        (concatStringsSep "\n" (map (domain: "@${domain} ${relayHost}") domains));
    services.postfix.mapFiles.sasl_relay_passwd = "/run/agenix/sasl_relay_passwd";
    age.secrets.sasl_relay_passwd.file = ../../secrets/sasl_relay_passwd.age;

    # Restrict certain recipients to mail from internal (authenticated) accounts only.
    # Any account that can authenticate to this server's submission port is "internal".
    services.postfix.settings.main = {
      smtpd_restriction_classes = "internal_only";
      internal_only = "permit_sasl_authenticated,permit_mynetworks,reject";
      smtpd_recipient_restrictions = lib.mkBefore [
        "check_recipient_access hash:/var/lib/postfix/conf/protected_recipients"
      ];
    };
    services.postfix.mapFiles.protected_recipients = pkgs.writeText "protected_recipients" ''
      agent@neet.dev internal_only
    '';

    # webmail is tailnet-only; the mail fqdn stays public for SMTP/IMAP and its cert
    services.roundcube = {
      enable = true;
      hostName = webmailHostname;
      extraConfig = ''
        # dovecot only exposes imaps (no plaintext 143 listener)
        $config['imap_host'] = "ssl://${config.mailserver.fqdn}:993";
        # starttls needed for authentication, so the fqdn required to match the certificate
        $config['smtp_server'] = "tls://${config.mailserver.fqdn}";
        $config['smtp_user'] = "%u";
        $config['smtp_pass'] = "%p";
      '';
    };

    # backups (roundcube keeps contacts/settings in a local postgres db)
    services.postgresqlBackup = {
      enable = true;
      databases = [ "roundcube" ];
    };
    backup.group."email".paths = [
      config.mailserver.storage.path
      config.services.postgresqlBackup.location
    ];
  };
}
