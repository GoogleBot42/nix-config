{ inputs }:
final: prev:

let
  system = prev.system;
in
{
  actual-server = prev.callPackage ./actualbudget { };
}
