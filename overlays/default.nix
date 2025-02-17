{ inputs }:
final: prev:

let
  system = prev.system;
in
{
  actual-server = prev.callPackage ./actualbudget { };

  # Copied entire package from nixpkgs to downgrade to python 3.11 since 3.12 is broken.
  # See: https://github.com/Py-KMS-Organization/py-kms/issues/117
  pykms = prev.callPackage ./pykms.nix { };
}
