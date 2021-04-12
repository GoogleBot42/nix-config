{ lib, config, ... }:

let
  cfg = config.services.murmur;
  certs = config.security.acme.certs;
in {
  options.services.murmur.domain = lib.mkOption {
    type = lib.types.str;
  };

  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [ cfg.port ];
    networking.firewall.allowedUDPPorts = [ cfg.port ];

    services.murmur = {
      sslCa = "${certs.${cfg.domain}.directory}/chain.pem";
      sslKey = "${certs.${cfg.domain}.directory}/key.pem";
      sslCert = "${certs.${cfg.domain}.directory}/fullchain.pem";
      welcometext = "Welcome to ${cfg.domain}";
    };

    services.nginx.virtualHosts."${cfg.domain}" = {
      enableACME = true;
      forceSSL = true;
    };

    # give mumble access to acme certs
    security.acme.certs.${cfg.domain} = {
      group = "murmur";
      postRun = "systemctl reload-or-restart murmur";
    };
    users.users.nginx.extraGroups = [ "murmur" ];
  };
}
