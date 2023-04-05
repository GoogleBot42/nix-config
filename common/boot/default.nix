{ lib, config, pkgs, ... }:

{
  imports = [
    ./firmware.nix
    ./efi.nix
    ./bios.nix
    ./remote-luks-unlock.nix
  ];
}
