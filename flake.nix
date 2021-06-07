{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-21.05";
    simple-nixos-mailserver.url = "gitlab:simple-nixos-mailserver/nixos-mailserver/nixos-21.05";
  };

  outputs = inputs: {

    nixosConfigurations =
    let
      mkSystem = system: path:
        inputsw.nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            path
            inputs.simple-nixos-mailserver.nixosModule
          ];
          specialArgs = { inherit inputs; };
        };
    in
    {
      "reg" = mkSystem "x86_64-linux" ./machines/reg/configuration.nix;
      "mitty" = mkSystem "x86_64-linux" ./machines/mitty/configuration.nix;
      "nanachi" = mkSystem "x86_64-linux" ./machines/nanachi/configuration.nix;
      "riko" = mkSystem "x86_64-linux" ./machines/riko/configuration.nix;
      "neetdev" = mkSystem "x86_64-linux" ./machines/neet.dev/configuration.nix;
      "s0" = mkSystem "aarch64-linux" ./machines/storage/s0/configuration.nix;
      "n1" = mkSystem "aarch64-linux" ./machines/compute/n1/configuration.nix;
    };
  };
}
