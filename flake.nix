{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/master";

    flake-utils.url = "github:numtide/flake-utils";

    nix-locate.url = "github:bennofs/nix-index";
    nix-locate.inputs.nixpkgs.follows = "nixpkgs";

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
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, ... }@inputs: {

    nixosConfigurations =
    let
      modules = system: [
        ./common
        inputs.simple-nixos-mailserver.nixosModule
        inputs.agenix.nixosModules.default
        inputs.dailybuild_modules.nixosModule
        inputs.archivebox.nixosModule
        ({ lib, ... }: {
          config.environment.systemPackages = [
            inputs.agenix.packages.${system}.agenix
          ];

          # because nixos specialArgs doesn't work for containers... need to pass in inputs a different way
          options.inputs = lib.mkOption { default = inputs; };
          options.currentSystem = lib.mkOption { default = system; };
        })
      ];

      mkSystem = system: nixpkgs: path:
        let
          allModules = modules system;
        in nixpkgs.lib.nixosSystem {
          inherit system;
          modules = allModules ++ [path];

          specialArgs = {
            inherit allModules;
          };
        };
    in
    {
      "ray" = mkSystem "x86_64-linux" nixpkgs-unstable ./machines/ray/configuration.nix;
      "nat" = mkSystem "aarch64-linux" nixpkgs ./machines/nat/configuration.nix;
      "liza" = mkSystem "x86_64-linux" nixpkgs ./machines/liza/configuration.nix;
      "ponyo" = mkSystem "x86_64-linux" nixpkgs ./machines/ponyo/configuration.nix;
      "router" = mkSystem "x86_64-linux" nixpkgs-unstable ./machines/router/configuration.nix;
      "s0" = mkSystem "x86_64-linux" nixpkgs-unstable ./machines/storage/s0/configuration.nix;
      "n1" = mkSystem "aarch64-linux" nixpkgs ./machines/compute/n1/configuration.nix;
      "n2" = mkSystem "aarch64-linux" nixpkgs ./machines/compute/n2/configuration.nix;
      "n3" = mkSystem "aarch64-linux" nixpkgs ./machines/compute/n3/configuration.nix;
      "n4" = mkSystem "aarch64-linux" nixpkgs ./machines/compute/n4/configuration.nix;
      "n5" = mkSystem "aarch64-linux" nixpkgs ./machines/compute/n5/configuration.nix;
      "n6" = mkSystem "aarch64-linux" nixpkgs ./machines/compute/n6/configuration.nix;
      "n7" = mkSystem "aarch64-linux" nixpkgs ./machines/compute/n7/configuration.nix;
    };

    packages = let
      mkKexec = system:
        (nixpkgs-unstable.lib.nixosSystem {
          inherit system;
          modules = [ ./machines/ephemeral/kexec.nix ];
        }).config.system.build.kexec_tarball;
      mkIso = system:
        (nixpkgs-unstable.lib.nixosSystem {
          inherit system;
          modules = [ ./machines/ephemeral/iso.nix ];
        }).config.system.build.isoImage;
    in {
      "x86_64-linux"."kexec" = mkKexec "x86_64-linux";
      "x86_64-linux"."iso" = mkIso "x86_64-linux";
      "aarch64-linux"."kexec" = mkKexec "aarch64-linux";
      "aarch64-linux"."iso" = mkIso "aarch64-linux";
    };
  };
}
