# Boot-path rehearsal for the s0 storage migration, run as QEMU guests on a
# workstation: a target system shaped like s0's new storage stanza (two LUKS
# containers, bcachefs root with subvolumes, mirrored ESPs) and a live ISO that
# installs it unattended onto blank virtual disks. See run.sh.
{ pkgs, nixpkgs', nix-index-database }:
let
  system = pkgs.stdenv.hostPlatform.system;
  mkSystem = modules: nixpkgs'.flake.lib.nixosSystem {
    inherit system;
    lib = nixpkgs'.lib;
    modules = [{ nixpkgs.pkgs = pkgs; }] ++ modules;
  };
  target = mkSystem [ ./target.nix ];
  live = mkSystem [
    ../../../ephemeral/minimal.nix
    nix-index-database.nixosModules.default
    ./live.nix
    { _module.args.targetSystem = target.config.system.build.toplevel; }
  ];
in
{
  s0-rehearsal-target = target.config.system.build.toplevel;
  s0-rehearsal-iso = live.config.system.build.images.iso;
}
