{
  inputs = {
    # nixpkgs
    nixpkgs.url = "github:NixOS/nixpkgs/master";

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
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    # Home Manager
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Mail Server
    simple-nixos-mailserver = {
      url = "gitlab:simple-nixos-mailserver/nixos-mailserver/master";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        nixpkgs-24_05.follows = "nixpkgs";
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

    # Radio
    radio = {
      url = "git+https://git.neet.dev/zuckerberg/radio.git?ref=main&rev=5bf607fed977d41a269942a7d1e92f3e6d4f2473";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
    radio-web = {
      url = "git+https://git.neet.dev/zuckerberg/radio-web.git";
      flake = false;
    };

    # Dailybot
    dailybuild_modules = {
      url = "git+https://git.neet.dev/zuckerberg/dailybot.git";
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
  };

  outputs = { self, nixpkgs, ... }@inputs:
    let
      machines = (import ./common/machine-info/moduleless.nix
        {
          inherit nixpkgs;
          assertionsModule = "${nixpkgs}/nixos/modules/misc/assertions.nix";
        }).machines;
      machineHosts = machines.hosts;
      machineRoles = machines.roles;
    in
    {
      nixosConfigurations =
        let
          modules = system: hostname: with inputs; [
            ./common
            simple-nixos-mailserver.nixosModule
            agenix.nixosModules.default
            dailybuild_modules.nixosModule
            nix-index-database.nixosModules.nix-index
            home-manager.nixosModules.home-manager
            self.nixosModules.kernel-modules
            ({ lib, ... }: {
              config = {
                nixpkgs.overlays = [ self.overlays.default ];

                environment.systemPackages = [
                  agenix.packages.${system}.agenix
                ];

                networking.hostName = hostname;

                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.users.googlebot = import ./home/googlebot.nix {
                  inherit hostname;
                  inherit machineRoles;
                };
              };

              # because nixos specialArgs doesn't work for containers... need to pass in inputs a different way
              options.inputs = lib.mkOption { default = inputs; };
              options.currentSystem = lib.mkOption { default = system; };
            })
          ];

          mkSystem = system: nixpkgs: path: hostname:
            let
              allModules = modules system hostname;

              # allow patching nixpkgs, remove this hack once this is solved: https://github.com/NixOS/nix/issues/3920
              patchedNixpkgsSrc = nixpkgs.legacyPackages.${system}.applyPatches {
                name = "nixpkgs-patched";
                src = nixpkgs;
                patches = [
                  ./patches/gamepadui.patch
                  ./patches/dont-break-nix-serve.patch
                ];
              };
              patchedNixpkgs = nixpkgs.lib.fix (self: (import "${patchedNixpkgsSrc}/flake.nix").outputs { self = nixpkgs; });

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

      packages =
        let
          mkKexec = system:
            (nixpkgs.lib.nixosSystem {
              inherit system;
              modules = [ ./machines/ephemeral/kexec.nix ];
            }).config.system.build.kexec_tarball;
          mkIso = system:
            (nixpkgs.lib.nixosSystem {
              inherit system;
              modules = [ ./machines/ephemeral/iso.nix ];
            }).config.system.build.isoImage;
        in
        {
          "x86_64-linux"."kexec" = mkKexec "x86_64-linux";
          "x86_64-linux"."iso" = mkIso "x86_64-linux";
          "aarch64-linux"."kexec" = mkKexec "aarch64-linux";
          "aarch64-linux"."iso" = mkIso "aarch64-linux";
        };

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

      checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) inputs.deploy-rs.lib;

      lib = nixpkgs.lib.extend (final: prev: import ./lib { lib = nixpkgs.lib; });
    };
}
