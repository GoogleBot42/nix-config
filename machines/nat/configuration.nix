{ ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  efi.enable = true;

  networking.hostName = "nat";
  networking.interfaces.ens160.useDHCP = true;
}
