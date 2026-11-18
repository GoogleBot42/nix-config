{ config, lib, pkgs, ... }:

# Serves the auto-generated service inventory (see /inventory) as a static
# tailnet-only site. The page is built from every machine's configuration in
# this flake, so it is always in step with whatever is deployed from master.

let
  cfg = config.services.service-inventory;
in
{
  options.services.service-inventory = {
    enable = lib.mkEnableOption "the fleet service inventory page";

    hostname = lib.mkOption {
      type = lib.types.str;
      example = "inventory.example.com";
      description = "Virtual host name the inventory is served under.";
    };

    useACMEHost = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Wildcard ACME certificate to reuse instead of requesting one for the hostname.";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = import ../../inventory {
        inherit pkgs lib;
        nixosConfigurations = config.inputs.self.nixosConfigurations;
        zones = import ../../dns/zones.nix;
        aclFile = ../../tailscale/acl.hujson;
        revision = config.system.configurationRevision;
        nixpkgsRevision = config.inputs.nixpkgs.rev or "unknown";
      };
      defaultText = lib.literalExpression "import ../../inventory { ... }";
      description = "Built inventory site.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.nginx.enable = true;
    services.nginx.virtualHosts.${cfg.hostname} = {
      tailscaleOnly = true;
      forceSSL = true;
      enableACME = lib.mkDefault (cfg.useACMEHost == null);
      useACMEHost = cfg.useACMEHost;
      root = cfg.package;
    };
  };
}
