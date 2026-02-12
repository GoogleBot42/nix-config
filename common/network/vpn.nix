{ config, lib, allModules, ... }:

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

    useOpenVPN = mkEnableOption "Uses OpenVPN instead of wireguard for PIA VPN connection";

    config = mkOption {
      type = types.anything;
      default = { };
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
    pia.wireguard.enable = !cfg.useOpenVPN;
    pia.wireguard.forwardPortForTransmission = !cfg.useOpenVPN;

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

      enableTun = cfg.useOpenVPN;
      privateNetwork = true;
      hostAddress = "172.16.100.1";
      localAddress = "172.16.100.2";

      config = {
        imports = allModules ++ [ cfg.config ];

        # networking.firewall.enable = mkForce false;
        networking.firewall.trustedInterfaces = [
          # completely trust internal interface to host
          "eth0"
        ];

        pia.openvpn.enable = cfg.useOpenVPN;
        pia.openvpn.server = "swiss.privacy.network"; # swiss vpn

        # TODO fix so it does run it's own resolver again
        # run it's own DNS resolver
        networking.useHostResolvConf = false;
        # services.resolved.enable = true;
        networking.nameservers = [ "1.1.1.1" "8.8.8.8" ];
      };
    };

    # load secrets the container needs
    age.secrets = config.containers.${cfg.containerName}.config.age.secrets;

    # forwarding for vpn container (only for OpenVPN)
    networking.nat.enable = mkIf cfg.useOpenVPN true;
    networking.nat.internalInterfaces = mkIf cfg.useOpenVPN [
      "ve-${cfg.containerName}"
    ];
    networking.ip_forward = mkIf cfg.useOpenVPN true;

    # assumes only one potential interface
    networking.usePredictableInterfaceNames = false;
    networking.nat.externalInterface = "eth0";
  };
}
