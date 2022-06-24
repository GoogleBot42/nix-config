{ config, pkgs, lib, allModules, ... }:

with lib;

let
  cfg = config.vpn-container;
in
{
  options.vpn-container = {
    enable = mkEnableOption "Enable VPN container";

    containerName = mkOption {
      type = types.str;
      default = "vpn";
      description = ''
        Name of the VPN container.
      '';
    };

    mounts = mkOption {
      type = types.listOf types.str;
      default = [ "/var/lib" ];
      example = "/home/example";
      description = ''
        List of mounts on the host to bind to the vpn container.
      '';
    };

    config = mkOption {
      type = types.anything;
      default = {};
      example = ''
        {
          services.nginx.enable = true;
        }
      '';
      description = ''
        NixOS config for the vpn container.
      '';
    };
  };

  config = mkIf cfg.enable {
    containers.${cfg.containerName} = {
      ephemeral = true;
      autoStart = true;

      bindMounts = mkMerge ([{
        "/run/agenix" = {
          hostPath = "/run/agenix";
          isReadOnly = true;
        };
      }] ++ (lists.forEach cfg.mounts (mount:
        {
          "${mount}" = {
            hostPath = mount;
            isReadOnly = false;
          };
        }
      )));

      enableTun = true;
      privateNetwork = true;
      hostAddress = "172.16.100.1";
      localAddress = "172.16.100.2";

      config = {
        imports = allModules ++ [cfg.config];

        nixpkgs.pkgs = pkgs;

        networking.firewall.enable = mkForce false;

        pia.enable = true;
        pia.server = "swiss.privacy.network"; # swiss vpn

        # run it's own DNS resolver
        networking.useHostResolvConf = false;
        services.resolved.enable = true;
      };
    };

    # load secrets the container needs
    age.secrets = config.containers.${cfg.containerName}.config.age.secrets;

    # forwarding for vpn container
    networking.nat.enable = true;
    networking.nat.internalInterfaces = [
      "ve-${cfg.containerName}"
    ];
    networking.ip_forward = true;

    # assumes only one potential interface
    networking.usePredictableInterfaceNames = false;
    networking.nat.externalInterface = "eth0";
  };
}