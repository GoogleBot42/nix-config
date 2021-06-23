{ config, ... }:

{
  imports = [
    ../common.nix
  ];

  networking.hostName = "n6";
}