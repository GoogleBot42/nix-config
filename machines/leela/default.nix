{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./networking.nix
    ./fan.nix
  ];

  services.openssh.openFirewall = false;
  services.resolved.enable = false;
  services.timesyncd.enable = true;
  services.lldpd.enable = true;

  # The USB-C serial console is the recovery path for a headless router.
  # Whoever holds that cable already has the U-Boot prompt, so a login
  # prompt on it protects nothing and only gets in the way.
  services.getty.autologinUser = "root";

  # Lease table and DNS cache counters for the fleet metrics scraper on kif
  # (common/server/metrics.nix, "DHCP leases" dashboard). The exporter asks
  # dnsmasq over loopback and reads the lease file directly; --expose_leases
  # turns on the per-lease series (MAC, address, hostname, expiry).
  services.prometheus.exporters.dnsmasq = {
    enable = true;
    extraFlags = [ "--expose_leases" ];
  };

  environment.systemPackages = with pkgs; [
    conntrack-tools
    ethtool
    iperf3
    nftables
  ];
}
