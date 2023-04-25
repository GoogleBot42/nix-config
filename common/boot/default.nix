{ lib, config, pkgs, ... }:

{
  imports = [
    ./firmware.nix
    ./efi.nix
    ./bios.nix
    ./kexec-luks.nix
    ./luks.nix
    ./remote-luks-unlock.nix
  ];
}
