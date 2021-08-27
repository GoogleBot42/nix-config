{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-21.05";
    nixpkgs-peertube.url = "github:GoogleBot42/nixpkgs/add-peertube-service";
    simple-nixos-mailserver.url = "gitlab:simple-nixos-mailserver/nixos-mailserver/nixos-21.05";
    agenix.url = "github:ryantm/agenix";

    # radio
    radio.url = "git+https://git.neet.dev/zuckerberg/radio.git?ref=main";
    radio-web.url = "git+https://git.neet.dev/zuckerberg/radio-web.git";
    radio-web.flake = false;

    # drastikbot
    drastikbot.url = "github:olagood/drastikbot/v2.1";
    drastikbot.flake = false;
    drastikbot_modules.url = "github:olagood/drastikbot_modules/v2.1";
    drastikbot_modules.flake = false;
    dailybuild_modules.url = "git+https://git.neet.dev/zuckerberg/dailybuild_modules.git";
    dailybuild_modules.flake = false;
  };

  outputs = inputs: {

    nixosConfigurations =
    let
      nixpkgs = inputs.nixpkgs;
      nixpkgs-peertube = inputs.nixpkgs-peertube;
      mkSystem = system: nixpkgs: path:
        nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            path
            ./common/common.nix
            inputs.simple-nixos-mailserver.nixosModule
            inputs.agenix.nixosModules.age
            {
              environment.systemPackages = [ inputs.agenix.defaultPackage.${system} ];
            }
          ];
          specialArgs = { inherit inputs; inherit system; };
        };
    in
    {
      "reg" = mkSystem "x86_64-linux" nixpkgs ./machines/reg/configuration.nix;
      "ray" = mkSystem "x86_64-linux" nixpkgs ./machines/ray/configuration.nix;
      "mitty" = mkSystem "x86_64-linux" nixpkgs ./machines/mitty/configuration.nix;
      "riko" = mkSystem "x86_64-linux" nixpkgs ./machines/riko/configuration.nix;
      "neetdev" = mkSystem "x86_64-linux" nixpkgs ./machines/neet.dev/configuration.nix;
      "liza" = mkSystem "x86_64-linux" nixpkgs-peertube ./machines/liza/configuration.nix;
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
