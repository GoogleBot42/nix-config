# Allows getting machine-info outside the scope of nixos configuration

{ nixpkgs ? import <nixpkgs> { }
, assertionsModule ? <nixpkgs/nixos/modules/misc/assertions.nix>
, machinesPath ? null
}:

{
  machines =
    (nixpkgs.lib.evalModules {
      modules = [
        ./default.nix
        assertionsModule
        {
          config = nixpkgs.lib.mkIf (machinesPath != null) {
            machines.machinesPath = machinesPath;
          };
        }
      ];
    }).config.machines;
}
