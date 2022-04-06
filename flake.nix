{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-21.11";

    flake-utils.url = "github:numtide/flake-utils";

    # mail server
    simple-nixos-mailserver.url = "gitlab:simple-nixos-mailserver/nixos-mailserver/nixos-21.11";
    simple-nixos-mailserver.inputs.nixpkgs.follows = "nixpkgs";
    simple-nixos-mailserver.inputs.nixpkgs-21_11.follows = "nixpkgs";

    # agenix
    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";

    # radio
    radio.url = "git+https://git.neet.dev/zuckerberg/radio.git?ref=main";
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

  outputs = inputs: {

    nixosConfigurations =
    let
      nixpkgs = inputs.nixpkgs;
      mkSystem = system: nixpkgs: path:
        nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            path
            ./common
            inputs.simple-nixos-mailserver.nixosModule
            inputs.agenix.nixosModule
            inputs.dailybuild_modules.nixosModule
            inputs.archivebox.nixosModule
            ({ lib, ... }: {
              config.environment.systemPackages = [ inputs.agenix.defaultPackage.${system} ];
              
              # because nixos specialArgs doesn't work for containers... need to pass in inputs a different way
              options.inputs = lib.mkOption { default = inputs; };
              options.currentSystem = lib.mkOption { default = system; };
            })
          ];
          # specialArgs = {};
        };
    in
    {
      "reg" = mkSystem "x86_64-linux" nixpkgs ./machines/reg/configuration.nix;
      "ray" = mkSystem "x86_64-linux" nixpkgs ./machines/ray/configuration.nix;
      "nat" = mkSystem "aarch64-linux" nixpkgs ./machines/nat/configuration.nix;
      "neetdev" = mkSystem "x86_64-linux" nixpkgs ./machines/neet.dev/configuration.nix;
      "liza" = mkSystem "x86_64-linux" nixpkgs ./machines/liza/configuration.nix;
      "s0" = mkSystem "aarch64-linux" nixpkgs ./machines/storage/s0/configuration.nix;
      "n1" = mkSystem "aarch64-linux" nixpkgs ./machines/compute/n1/configuration.nix;
      "n2" = mkSystem "aarch64-linux" nixpkgs ./machines/compute/n2/configuration.nix;
      "n3" = mkSystem "aarch64-linux" nixpkgs ./machines/compute/n3/configuration.nix;
      "n4" = mkSystem "aarch64-linux" nixpkgs ./machines/compute/n4/configuration.nix;
      "n5" = mkSystem "aarch64-linux" nixpkgs ./machines/compute/n5/configuration.nix;
      "n6" = mkSystem "aarch64-linux" nixpkgs ./machines/compute/n6/configuration.nix;
      "n7" = mkSystem "aarch64-linux" nixpkgs ./machines/compute/n7/configuration.nix;
    };
  };
}
