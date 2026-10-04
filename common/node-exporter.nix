{ config, lib, ... }:

# Every tailnet machine exposes node_exporter for the fleet metrics scraper
# (common/server/metrics.nix). Port 9100 is reachable only over tailscale0,
# which the firewall trusts; it is never opened on any other interface.

{
  config = lib.mkIf config.services.tailscale.enable {
    services.prometheus.exporters.node = {
      enable = lib.mkDefault true;
      enabledCollectors = [ "systemd" ];
    };
  };
}
