{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    simple-nixos-mailserver.url = "gitlab:simple-nixos-mailserver/nixos-mailserver/master";
  };

  outputs = { self, nixpkgs, peertube }: {

    nixosConfigurations = {
      "reg" = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ ./machines/reg/configuration.nix ];
      };
      "mitty" = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ ./machines/mitty/configuration.nix ];
      };
      "nanachi" = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ ./machines/nanachi/configuration.nix ];
      };
      "riko" = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ ./machines/riko/configuration.nix ];
      };
      "neetdev" = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./machines/neet.dev/configuration.nix
          simple-nixos-mailserver.nixosModule
        ];
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
