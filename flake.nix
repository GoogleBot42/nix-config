{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/master";
    # nixpkgs-patch-howdy.url = "https://github.com/NixOS/nixpkgs/pull/216245.diff";
    # nixpkgs-patch-howdy.flake = false;

    flake-utils.url = "github:numtide/flake-utils";

    # mail server
    simple-nixos-mailserver.url = "gitlab:simple-nixos-mailserver/nixos-mailserver/nixos-22.05";
    simple-nixos-mailserver.inputs.nixpkgs.follows = "nixpkgs";

    # agenix
    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";

    # radio
    radio.url = "git+https://git.neet.dev/zuckerberg/radio.git?ref=main&rev=5bf607fed977d41a269942a7d1e92f3e6d4f2473";
    radio.inputs.nixpkgs.follows = "nixpkgs";
    radio.inputs.flake-utils.follows = "flake-utils";
    radio-web.url = "git+https://git.neet.dev/zuckerberg/radio-web.git";
    radio-web.flake = false;

    # drastikbot
    dailybuild_modules.url = "git+https://git.neet.dev/zuckerberg/dailybuild_modules.git";
    dailybuild_modules.inputs.nixpkgs.follows = "nixpkgs";
    dailybuild_modules.inputs.flake-utils.follows = "flake-utils";

    # archivebox
    archivebox.url = "git+https://git.neet.dev/zuckerberg/archivebox.git";
    archivebox.inputs.nixpkgs.follows = "nixpkgs";
    archivebox.inputs.flake-utils.follows = "flake-utils";

    # nixos config deployment
    deploy-rs.url = "github:serokell/deploy-rs";
    deploy-rs.inputs.nixpkgs.follows = "nixpkgs";
    deploy-rs.inputs.utils.follows = "simple-nixos-mailserver/utils";

    # prebuilt nix-index database
    nix-index-database.url = "github:Mic92/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";

    nixpkgs-hostapd-pr.url = "https://github.com/NixOS/nixpkgs/pull/222536.patch";
    nixpkgs-hostapd-pr.flake = false;
  };

  outputs = { self, nixpkgs, ... }@inputs:
    let
      machines = (import ./common/machine-info/moduleless.nix
        {
          inherit nixpkgs;
          assertionsModule = "${nixpkgs}/nixos/modules/misc/assertions.nix";
        }).machines.hosts;
    in
    {
      nixosConfigurations =
        let
          modules = system: with inputs; [
            ./common
            simple-nixos-mailserver.nixosModule
            agenix.nixosModules.default
            dailybuild_modules.nixosModule
            archivebox.nixosModule
            nix-index-database.nixosModules.nix-index
            ({ lib, ... }: {
              config.environment.systemPackages = [
                agenix.packages.${system}.agenix
              ];

              # because nixos specialArgs doesn't work for containers... need to pass in inputs a different way
              options.inputs = lib.mkOption { default = inputs; };
              options.currentSystem = lib.mkOption { default = system; };
            })
          ];

          mkSystem = system: nixpkgs: path:
            let
              allModules = modules system;

              # allow patching nixpkgs, remove this hack once this is solved: https://github.com/NixOS/nix/issues/3920
              patchedNixpkgsSrc = nixpkgs.legacyPackages.${system}.applyPatches {
                name = "nixpkgs-patched";
                src = nixpkgs;
                patches = [
                  inputs.nixpkgs-hostapd-pr
                ];
              };
              patchedNixpkgs = nixpkgs.lib.fix (self: (import "${patchedNixpkgsSrc}/flake.nix").outputs { self = nixpkgs; });

            in
            patchedNixpkgs.lib.nixosSystem {
              inherit system;
              modules = allModules ++ [ path ];

              specialArgs = {
                inherit allModules;
              };
            };
        in
        nixpkgs.lib.mapAttrs
          (hostname: cfg:
            mkSystem cfg.arch nixpkgs cfg.configurationPath)
          machines;

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
          machines;

      checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) inputs.deploy-rs.lib;
    };
}
