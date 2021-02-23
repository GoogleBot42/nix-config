{ config, pkgs, ... }:

#let
#  pithos = pkgs.pithos.overrideAttrs (old: rec {
#    pname = "pithos";
#    version = "1.5.1";
#    src = pkgs.fetchFromGitHub {
#      owner = pname;
#      repo  = pname;
#      rev = version;
#      sha256 = "il7OAALpHFZ6wjco9Asp04zWHCD8Ni+iBdiJWcMiQA4=";
#    };
#  });
#in
{
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

#  nixpkgs.config.packageOverrides = pkgs: {
#    pithos = pkgs.pithos.overrideAttrs (old: rec {
#      pname = "pithos";
#      version = "1.5.1";
#      pithosSrc = pkgs.fetchFromGitHub {
#        owner = pname;
#        repo  = pname;
#        rev = version;
#        sha256 = "il7OAALpHFZ6wjco9Asp04zWHCD8Ni+iBdiJWcMiQA4=";
#      };
#    });
#  };

  users.users.googlebot.packages = with pkgs; [
    pithos
  ];
}
