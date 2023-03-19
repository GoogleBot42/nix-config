{ config, pkgs, lib, ... }:

# keeps peer to peer connections alive with a periodic ping

with lib;
with builtins;

# todo auto restart

let
  cfg = config.keepalive-ping;

  serviceTemplate = host:
  {
    "keepalive-ping@${host}" = {
      description = "Periodic ping keep alive for ${host} connection";

      requires = [ "network-online.target" ];
      after = [ "network.target" "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig.Restart="always";

      path = with pkgs; [ iputils ];

      script = ''
        ping -i ${cfg.delay} ${host} &>/dev/null
      '';
    };
  };

  combineAttrs = foldl recursiveUpdate {};

  serviceList = map serviceTemplate cfg.hosts;

  services = combineAttrs serviceList;
in {
  options.keepalive-ping = {
    enable = mkEnableOption "Enable keep alive ping task";
    hosts = mkOption {
      type = types.listOf types.str;
      default = [];
      description = ''
        Hosts to ping periodically
      '';
    };
    delay = mkOption {
      type = types.str;
      default = "60";
      description = ''
        Ping interval in seconds of periodic ping per host being pinged
      '';
    };
  };

  config = mkIf cfg.enable {
    systemd.services = services;
  };
}