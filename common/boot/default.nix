{ lib, config, pkgs, ... }:

{
  imports = [
    ./firmware.nix
    ./efi.nix
    ./bios.nix
    ./luks.nix
  ];
}