{ lib, config, ... }:

let
  cfg = config.services.nginx;
  tailscaleOnlyEnabled = builtins.any (vhostCfg: vhostCfg.tailscaleOnly) (lib.attrValues cfg.virtualHosts);
  wildcardACMEHosts = lib.unique (
    lib.filter (host: host != null) (map (vhostCfg: vhostCfg.useACMEHost) (lib.attrValues cfg.virtualHosts))
  );
  hasWildcardACMEHosts = wildcardACMEHosts != [ ];
  mkWildcardCert = host: {
    dnsProvider = "digitalocean";
    environmentFile = "/run/agenix/digitalocean-dns-credentials";
    extraDomainNames = [ "*.${host}" ];
    group = lib.mkDefault cfg.group;
    dnsResolver = "1.1.1.1:53";
    dnsPropagationCheck = false;
  };
in
{
  options.services.nginx = {
    openFirewall = lib.mkEnableOption "Open firewall ports 80 and 443";

    tailscaleListenAddress = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "100.76.85.13";
      description = "Address on the host's Tailscale interface to bind Tailscale-only virtual hosts to.";
    };

    virtualHosts = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule ({ config, ... }: {
        options.tailscaleOnly = lib.mkEnableOption "bind this virtual host only to the host's Tailscale listen address";

        config = lib.mkMerge [
          (lib.mkIf config.tailscaleOnly {
            listenAddresses = [ cfg.tailscaleListenAddress ];
          })
          (lib.mkIf (config.useACMEHost != null) {
            enableACME = false;
          })
        ];
      }));
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !tailscaleOnlyEnabled || cfg.tailscaleListenAddress != null;
        message = "services.nginx.tailscaleListenAddress must be set when any nginx virtual host has tailscaleOnly = true.";
      }
      {
        assertion = !tailscaleOnlyEnabled || config.services.tailscale.enable;
        message = "services.tailscale.enable must be true when any nginx virtual host has tailscaleOnly = true.";
      }
    ];

    services.nginx = {
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
    };

    services.nginx.openFirewall = lib.mkDefault true;

    age.secrets.digitalocean-dns-credentials = lib.mkIf hasWildcardACMEHosts {
      file = ../../secrets/digitalocean-dns-credentials.age;
    };

    security.acme.certs = lib.listToAttrs (
      map (host: lib.nameValuePair host (mkWildcardCert host)) wildcardACMEHosts
    );

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ 80 443 ];
  };
}
