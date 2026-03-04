{ config, lib, pkgs, ... }:

let
  cfg = config.services.unifi;
in
{
  options.services.unifi = {
    # Open select Unifi ports instead of using openFirewall to avoid opening access to unifi's control panel
    openMinimalFirewall = lib.mkEnableOption "Open bare minimum firewall ports";
  };

  config = lib.mkIf cfg.enable {
    services.unifi.unifiPackage = pkgs.unifi;
    services.unifi.mongodbPackage = pkgs.mongodb-7_0;

    # The upstream module sets KillSignal=SIGCONT so systemd doesn't interfere
    # with UniFi's self-managed shutdown. But UniFi's Java process crashes during
    # shutdown (Spring context already closed) leaving mongod orphaned in the
    # cgroup. With the default KillMode=control-group, mongod only gets SIGCONT
    # (a no-op) and runs until the 5min timeout triggers SIGKILL.
    # KillMode=mixed sends SIGCONT to the main process but SIGTERM to remaining
    # children, giving mongod a clean shutdown instead of SIGKILL.
    systemd.services.unifi.serviceConfig.KillMode = "mixed";

    networking.firewall = lib.mkIf cfg.openMinimalFirewall {
      allowedUDPPorts = [
        3478 # STUN
        10001 # used for device discovery.
      ];
      allowedTCPPorts = [
        8080 # Used for device and application communication.
      ];
    };
  };
}
