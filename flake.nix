{ config, pkgs, ... }:

{
  inputs.nixpkgs.url = "inputs.nixpkgs.url = github:NixOS/nixpkgs/nixos-20.09";

  outputs = { nixpkgs, ... }: {
  nixosConfigurations = {
    reg = nixpkgs.lib.nixosSystem {
      modules = [ ./reg/configuration.nix ];
      system = "x86_64-linux";
    };
  };
};
}