{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # don't use remote builders
  nix.distributedBuilds = lib.mkForce false;

}
