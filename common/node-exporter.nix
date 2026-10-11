{ config, lib, pkgs, ... }:

# Every tailnet machine exposes node_exporter for the fleet metrics scraper
# (common/server/metrics.nix). Port 9100 is reachable only over tailscale0,
# which the firewall trusts; it is never opened on any other interface.

let
  cfg = config.services.prometheus.exporters.node;
in
{
  config = lib.mkIf config.services.tailscale.enable {
    services.prometheus.exporters.node = {
      enable = lib.mkDefault true;
      enabledCollectors = [ "systemd" ];
    };

    # node_exporter's rapl collector (on by default) reads the CPU energy
    # counters under /sys/class/powercap, but the kernel creates energy_uj
    # root-only (0400) because fine-grained energy readings are a side
    # channel. The exporter runs unprivileged, so open the counters to its
    # group instead of handing the whole service a capability. Machines
    # without RAPL (VMs) skip this via the path condition.
    systemd.services.rapl-energy-permissions = lib.mkIf cfg.enable {
      description = "Make RAPL energy counters readable by node_exporter";
      wantedBy = [ "multi-user.target" ];
      before = [ "prometheus-node-exporter.service" ];
      unitConfig.ConditionPathExists = "/sys/class/powercap/intel-rapl";
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        for f in /sys/class/powercap/intel-rapl:*/energy_uj; do
          ${pkgs.coreutils}/bin/chgrp ${cfg.group} "$f"
          ${pkgs.coreutils}/bin/chmod 0440 "$f"
        done
      '';
    };
  };
}
