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
  unifi8 = prev.unifi.overrideAttrs (oldAttrs: rec {
    version = "8.1.113";
    src = prev.fetchurl {
      url = "https://dl.ui.com/unifi/8.1.113/unifi_sysvinit_all.deb";
      sha256 = "1knm+l8MSb7XKq2WIbehAnz7loRPjgnc+R98zpWKEAE=";
    };
  });
}
