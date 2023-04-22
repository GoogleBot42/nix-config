# Allows getting machine-info outside the scope of nixos configuration

{ nixpkgs ? import <nixpkgs> { }
, assertionsModule ? <nixpkgs/nixos/modules/misc/assertions.nix>
}:

{
  machines =
    (nixpkgs.lib.evalModules {
      modules = [
        ./default.nix
        assertionsModule
      ];
    }).config.machines;
}
