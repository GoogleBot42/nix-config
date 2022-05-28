{ config, lib, ... }:

{
  imports = [
    ./hosts.nix
    ./pia-openvpn.nix
    ./vpn.nix
    ./zerotier.nix
  ];
}