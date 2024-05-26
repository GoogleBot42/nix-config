{ inputs }:
final: prev:

let
  system = prev.system;
  frigatePkgs = inputs.nixpkgs-frigate.legacyPackages.${system};
in
{
  # It seems that libedgetpu needs to be built with the newer version of tensorflow in nixpkgs
  # but I am lazy so I instead just downgrade by using the old nixpkgs
  libedgetpu = frigatePkgs.callPackage ./libedgetpu { };
  frigate = frigatePkgs.frigate;

  actual-server = prev.callPackage ./actualbudget { };
}
