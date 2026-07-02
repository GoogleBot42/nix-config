{
  inputs = {
    # nixpkgs
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-ai-edge-litert.url = "github:NixOS/nixpkgs/567a49d1913ce81ac6e9582e3553dd90a955875f";

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

    # Hindsight memory server (vectorize-io). No upstream flake; consumed as a
    # bare source tree and packaged via the uv2nix toolchain from hermes-agent.
    hindsight-src = {
      url = "github:vectorize-io/hindsight";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, ... }@inputs:
    let
      machineHosts = (import ./common/machine-info/moduleless.nix
        {
          inherit nixpkgs;
          assertionsModule = "${nixpkgs}/nixos/modules/misc/assertions.nix";
        }).machines.hosts;
    in
    {
      nixosConfigurations =
        let
          modules = system: hostname: patchedInputs: with inputs; [
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
              # nixpkgs is replaced with the patched tree so consumers (incus guest
              # eval, workspace nixPath/registry pins) see the same nixpkgs the host
              # was built from.
              options.inputs = lib.mkOption { default = patchedInputs; };
              options.currentSystem = lib.mkOption { default = system; };
            })
          ];

          mkSystem = system: nixpkgs: path: hostname:
            let
              # allow patching nixpkgs, remove this hack once this is solved: https://github.com/NixOS/nix/issues/3920
              patchedNixpkgsSrc = nixpkgs.legacyPackages.${system}.applyPatches {
                name = "nixpkgs-patched";
                src = nixpkgs;
                patches = [ ];
              };
              patchedNixpkgs = nixpkgs.lib.fix (self: (import "${patchedNixpkgsSrc}/flake.nix").outputs { self = nixpkgs; });

              # The flake outputs attrset lacks an outPath, so graft one on to make
              # the patched tree usable wherever a flake input is expected
              # (string interpolation for nixPath, nix.registry pins, etc.).
              patchedInputs = inputs // {
                nixpkgs = patchedNixpkgs // { outPath = "${patchedNixpkgsSrc}"; };
              };

              allModules = modules system hostname patchedInputs;
            in
            patchedNixpkgs.lib.nixosSystem {
              inherit system;
              modules = allModules ++ [ path ];

              specialArgs = {
                inherit allModules;
                lib = self.lib;
                nixos-hardware = inputs.nixos-hardware;
              };
            };
        in
        nixpkgs.lib.mapAttrs
          (hostname: cfg:
            mkSystem cfg.arch nixpkgs cfg.configurationPath hostname)
          machineHosts;

      # kexec produces a tarball; for a self-extracting bundle see:
      # https://github.com/nix-community/nixos-generators/blob/master/formats/kexec.nix#L60
      packages =
        let
          supportedSystems = [
            "x86_64-linux"
            "aarch64-linux"
          ];

          pkgsFor = system: import nixpkgs {
            inherit system;
            overlays = [ self.overlays.default ];
          };

          mkEphemeral = pkgsForSystem: nixpkgs.lib.nixosSystem {
            system = pkgsForSystem.stdenv.hostPlatform.system;
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

      lib = nixpkgs.lib.extend (final: prev: import ./lib { lib = nixpkgs.lib; });
    };
}
