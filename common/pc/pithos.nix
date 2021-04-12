{ lib, config, pkgs, ... }:

let
  cfg = config.de;
in {
  config = lib.mkIf cfg.enable {
    nixpkgs.overlays = [
      (self: super: {
        pithos = super.pithos.overrideAttrs (old: rec {
          pname = "pithos";
          version = "1.5.1";
          src = super.fetchFromGitHub {
            owner = pname;
            repo  = pname;
            rev = version;
            sha256 = "il7OAALpHFZ6wjco9Asp04zWHCD8Ni+iBdiJWcMiQA4=";
          };
        });
      })
    ];

    users.users.googlebot.packages = with pkgs; [
      pithos
    ];
  };
}
