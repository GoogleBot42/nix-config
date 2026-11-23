{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./networking.nix
    ./wan-failover.nix
    ./cell-backup-check.nix
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

  environment.systemPackages = with pkgs; [
    conntrack-tools
    ethtool
    iperf3
    nftables
  ];
}
