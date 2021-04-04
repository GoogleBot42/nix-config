{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }: {

    nixosConfigurations = {
      "reg" = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ ./reg/configuration.nix ];
      };
      "mitty" = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ ./mitty/configuration.nix ];
      };
      "nanachi" = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ ./nanachi/configuration.nix ];
      };
      "neetdev" = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ ./neet.dev/configuration.nix ];
      };
    };
  };
}
