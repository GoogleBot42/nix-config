# Central flake check wiring. Keep test registration here so flake.nix only
# imports the test abstraction instead of growing per-test plumbing.
{ inputs, self }:
let
  inherit (inputs) nixpkgs;

  # deploy-rs exposes checks for every supported system; keep only the Linux
  # deploy checks so the flake check set matches the NixOS hosts we actually deploy.
  linuxDeployLibs = nixpkgs.lib.filterAttrs
    (system: _: nixpkgs.lib.hasSuffix "-linux" system)
    inputs.deploy-rs.lib;

  unitChecksFor = system:
    let
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      pia-vpn-port-refresh = import ./pia-vpn-port-refresh-check.nix { inherit pkgs; };
    };
in
builtins.mapAttrs
  (system: deployLib:
  (deployLib.deployChecks self.deploy) // unitChecksFor system)
  linuxDeployLibs
