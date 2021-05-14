{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    peertube.url = "git+https://git.immae.eu/perso/Immae/Config/Nix.git?dir=flakes/peertube&rev=ded643e14096a7cb166c78dd961cf68fb4ddb0cf";
  };

  outputs = { self, nixpkgs, peertube }: {

    nixosConfigurations = {
      "reg" = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ ./machines/reg/configuration.nix ];
      };
      "mitty" = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./machines/mitty/configuration.nix
          peertube.nixosModule
        ];
      };
      "nanachi" = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ ./machines/nanachi/configuration.nix ];
      };
      "neetdev" = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ ./machines/neet.dev/configuration.nix ];
      };
      "s0" = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [ ./machines/storage/s0/configuration.nix ];
      };
      "n1" = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [ ./machines/compute/n1/configuration.nix ];
      };
    };
  };
}
