{
  inputs = {
    # nixpkgs
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Common Utils Among flake inputs
    systems.url = "github:nix-systems/default";
    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs.systems.follows = "systems";
    };
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };

    # NixOS hardware
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Home Manager
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Mail Server
    simple-nixos-mailserver = {
      url = "gitlab:simple-nixos-mailserver/nixos-mailserver";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-compat.follows = "flake-compat";
      };
    };

    # Agenix
    agenix = {
      url = "github:ryantm/agenix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        systems.follows = "systems";
        home-manager.follows = "home-manager";
      };
    };

    # Dailybot
    dailybot = {
      url = "github:GoogleBot42/dailybot";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };

    # NixOS deployment
    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-compat.follows = "flake-compat";
        utils.follows = "flake-utils";
      };
    };

    # Prebuilt nix-index database
    nix-index-database = {
      url = "github:Mic92/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # MicroVM support
    microvm = {
      url = "github:astro/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Up to date claude-code
    claude-code-nix = {
      url = "github:sadjow/claude-code-nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };

    # Hermes agent (Nous Research)
    hermes-agent = {
      url = "github:NousResearch/hermes-agent";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        # Collapse duplicate copies of pyproject-nix and uv2nix that the
        # hermes-agent flake otherwise pulls in at multiple revs.
        pyproject-build-systems.inputs.pyproject-nix.follows = "hermes-agent/pyproject-nix";
        pyproject-build-systems.inputs.uv2nix.follows = "hermes-agent/uv2nix";
        uv2nix.inputs.pyproject-nix.follows = "hermes-agent/pyproject-nix";
      };
    };

    # Hindsight memory server, packaged from source in its own CI-verified
    # flake (daily auto-updated; runtime-checked before its lock moves).
    # Deliberately no `follows`: the pinned closure is exactly what that CI
    # built, checked, and pushed to the attic cache.
    hindsight-nix.url = "git+https://git.neet.dev/zuckerberg/hindsight-nix";
  };

  outputs = { self, nixpkgs, ... }@inputs:
    let
      machineHosts = (import ./common/machine-info/moduleless.nix
        {
          inherit nixpkgs;
          assertionsModule = "${nixpkgs}/nixos/modules/misc/assertions.nix";
        }).machines.hosts;

      # Extend a nixpkgs lib with the custom helpers from ./lib.
      extendLib = baseLib: baseLib.extend (final: prev: import ./lib { lib = final; });

      # Patches applied to the nixpkgs source tree itself (not to individual
      # packages; those belong in overlays). Remove this whole mechanism once
      # https://github.com/NixOS/nix/issues/3920 is solved.
      nixpkgsPatches = [
        ./patches/openvino-2026.2.0-for-ai-edge-litert.patch
      ];

      # Re-import the patched tree as a flake with a real `self` fixpoint so
      # everything derived from it — including the flake registry pin
      # (nixpkgs.flake.source) baked into each machine — points at the patched
      # tree. The patched store path has no git metadata of its own, so the
      # base input's is grafted on for `lib.version` / nixos-version info.
      patchNixpkgs = system:
        let
          src = nixpkgs.legacyPackages.${system}.applyPatches {
            name = "nixpkgs-patched";
            src = nixpkgs;
            patches = nixpkgsPatches;
          };
          metadata = {
            outPath = src;
            inherit (nixpkgs) lastModified lastModifiedDate narHash;
          } // nixpkgs.lib.optionalAttrs (nixpkgs ? rev) {
            inherit (nixpkgs) rev shortRev;
          };
        in
        nixpkgs.lib.fix (self:
          (import "${src}/flake.nix").outputs { inherit self; } // metadata);

      # Systems flake outputs are provided for. Machine arches are always a
      # subset of these (enforced by the arch enum in machine-info).
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];

      # One nixpkgs flake + extended lib per system, shared by every machine
      # and package output of that system instead of re-evaluated per use.
      # While the patch list is empty the plain input is used directly,
      # skipping the full-tree copy (and import-from-derivation) that
      # applyPatches costs.
      nixpkgsFor = nixpkgs.lib.genAttrs supportedSystems (system:
        let
          flake = if nixpkgsPatches == [ ] then nixpkgs else patchNixpkgs system;
        in
        {
          inherit flake;
          lib = extendLib flake.lib;
        });
    in
    {
      nixosConfigurations =
        let
          modules = system: hostname: with inputs; [
            ./common
            simple-nixos-mailserver.nixosModules.default
            agenix.nixosModules.default
            dailybot.nixosModule
            nix-index-database.nixosModules.default
            home-manager.nixosModules.home-manager
            microvm.nixosModules.host
            self.nixosModules.kernel-modules
            ({ lib, ... }: {
              config = {
                nixpkgs.overlays = [
                  self.overlays.default
                  inputs.claude-code-nix.overlays.default
                ];

                environment.systemPackages = [
                  agenix.packages.${system}.agenix
                ];

                networking.hostName = hostname;
                # Query with: nixos-version --configuration-revision
                system.configurationRevision = self.rev or self.dirtyRev or "unknown";

                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.users.googlebot = import ./home/googlebot.nix;
              };

              # because nixos specialArgs doesn't work for containers... need to pass in inputs a different way
              options.inputs = lib.mkOption { default = inputs; };
              options.currentSystem = lib.mkOption { default = system; };
            })
          ];

          mkSystem = system: path: hostname:
            let
              allModules = modules system hostname;
              nixpkgs' = nixpkgsFor.${system};
            in
            nixpkgs'.flake.lib.nixosSystem {
              inherit system;
              lib = nixpkgs'.lib;
              modules = allModules ++ [ path ];

              specialArgs = {
                inherit allModules;
                nixos-hardware = inputs.nixos-hardware;
              };
            };
        in
        nixpkgs.lib.mapAttrs
          (hostname: cfg:
            mkSystem cfg.arch cfg.configurationPath hostname)
          machineHosts;

      # kexec produces a tarball; for a self-extracting bundle see:
      # https://github.com/nix-community/nixos-generators/blob/master/formats/kexec.nix#L60
      packages =
        let
          pkgsFor = system: import nixpkgsFor.${system}.flake {
            inherit system;
            overlays = [ self.overlays.default ];
          };

          mkEphemeral = pkgsForSystem:
            let
              system = pkgsForSystem.stdenv.hostPlatform.system;
              nixpkgs' = nixpkgsFor.${system};
            in
            nixpkgs'.flake.lib.nixosSystem {
              inherit system;
              lib = nixpkgs'.lib;
              modules = [
                { nixpkgs.pkgs = pkgsForSystem; }
                ./machines/ephemeral/minimal.nix
                inputs.nix-index-database.nixosModules.default
              ];
            };

          mkPackages = system:
            let
              pkgs = pkgsFor system;
              ephemeral = mkEphemeral pkgs;
            in
            {
              dnscontrolConfig = import ./dns/render.nix { inherit pkgs; };
            }
            // nixpkgs.lib.optionalAttrs (system == "x86_64-linux") {
              kexec = ephemeral.config.system.build.images.kexec;
              iso = ephemeral.config.system.build.images.iso;
            };
        in
        nixpkgs.lib.genAttrs supportedSystems mkPackages;

      overlays.default = import ./overlays { inherit inputs; };
      nixosModules.kernel-modules = import ./overlays/kernel-modules;

      deploy.nodes =
        let
          mkDeploy = configName: arch: hostname: {
            inherit hostname;
            magicRollback = false;
            sshUser = "root";
            profiles.system.path = inputs.deploy-rs.lib.${arch}.activate.nixos self.nixosConfigurations.${configName};
          };
        in
        nixpkgs.lib.mapAttrs
          (hostname: cfg:
            mkDeploy hostname cfg.arch (builtins.head cfg.hostNames))
          machineHosts;

      checks = import ./tests { inherit inputs self; };

      lib = extendLib nixpkgs.lib;
    };
}
