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

      # Sandboxed-workspace guest systems are only referenced through their
      # image tarballs, so their store paths never appear in any host closure.
      # Root them here so CI builds them explicitly and pushes their closures
      # to the binary cache (see .gitea/scripts/build-and-cache.sh).
      workspace-guests = pkgs.linkFarm "workspace-guests"
        (nixpkgs.lib.concatLists (nixpkgs.lib.mapAttrsToList
          (host: cfg: nixpkgs.lib.optional
            (cfg.pkgs.stdenv.hostPlatform.system == system
              && cfg.config.system.build ? sandboxedWorkspaceGuests)
            { name = host; path = cfg.config.system.build.sandboxedWorkspaceGuests; })
          self.nixosConfigurations));
    };
in
builtins.mapAttrs
  (system: deployLib:
  (deployLib.deployChecks self.deploy) // unitChecksFor system)
  linuxDeployLibs
