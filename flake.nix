{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }: {

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
      "neetdev" = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ ./machines/neet.dev/configuration.nix ];
      };
      "s0" = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [ ./machines/storage/s0/configuration.nix ];
      };
    };
  };
}
