{ config, pkgs, lib, ... }:

let
  internal = "end0";
  wireless = "wlan0";
  internal-gateway-ip = "192.168.0.1";
  internal-ip-lower = "192.168.0.10";
  internal-ip-upper = "192.168.0.100";
in
{
  imports = [
    ./hardware-configuration.nix
  ];

  enableExtraSubstituters = false;

  # networking.interfaces.${internal}.ipv4.addresses = [{
  #   address = internal-gateway-ip;
  #   prefixLength = 24;
  # }];

  # DHCP on all interfaces except for the internal interface
  networking.useDHCP = true;
  networking.interfaces.${internal}.useDHCP = true;
  networking.interfaces.${wireless}.useDHCP = true;

  # Enable NAT
  networking.ip_forward = true;
  networking.nat = {
    enable = true;
    internalInterfaces = [ internal ];
    externalInterface = wireless;
  };

  networking.wireless = {
    enable = true;
    networks = {
      "Pixel_6054".psk = "@PSK_Pixel_6054@";
    };
    interfaces = [ wireless ];
    environmentFile = "/run/agenix/hostspot-passwords";
  };
  age.secrets.hostspot-passwords.file = ../../secrets/hostspot-passwords.age;

  # dnsmasq for internal interface
  services.dnsmasq = {
    enable = true;
    settings = {
      server = [ "1.1.1.1" "8.8.8.8" ];
      dhcp-range = "${internal-ip-lower},${internal-ip-upper},24h";
      dhcp-option = [
        "option:router,${internal-gateway-ip}"
        "option:broadcast,10.0.0.255"
        "option:ntp-server,0.0.0.0"
      ];
    };
  };

  networking.firewall.interfaces.${internal}.allowedTCPPorts = [
    53 # dnsmasq
  ];

  # Make it appear we are not using phone tethering to the ISP
  networking.firewall = {
    extraCommands = ''
      iptables -t mangle -A POSTROUTING -o ${wireless} -j TTL --ttl-set 65
    '';
  };
}
