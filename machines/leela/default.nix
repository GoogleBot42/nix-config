{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./networking.nix
  ];

  services.openssh.openFirewall = false;
  services.resolved.enable = false;
  services.timesyncd.enable = true;
  services.lldpd.enable = true;

  environment.systemPackages = with pkgs; [
    conntrack-tools
    ethtool
    iperf3
    nftables
  ];
}
