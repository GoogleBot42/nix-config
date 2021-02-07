{ config, ... }:

let 
  murmurPort = 23563;
  domain = "voice.neet.space";
  certs = config.security.acme.certs;
in {
  config.networking.firewall.allowedTCPPorts = [ murmurPort ];
  config.networking.firewall.allowedUDPPorts = [ murmurPort ];

  config.services.murmur = {
    enable = true;
    port = murmurPort;
    sslCa = "${certs.${domain}.directory}/chain.pem";
    sslKey = "${certs.${domain}.directory}/key.pem";
    sslCert = "${certs.${domain}.directory}/fullchain.pem";
    welcometext = "Welcome to ${domain}";
  };

  config.services.nginx.virtualHosts."${domain}" = {
    enableACME = true;
    forceSSL = true;
  };

  # give mumble access to acme certs
  config.security.acme.certs.${domain} = {
    group = "murmur";
    postRun = "systemctl reload-or-restart murmur";
  };
  config.users.users.nginx.extraGroups = [ "murmur" ];
}
