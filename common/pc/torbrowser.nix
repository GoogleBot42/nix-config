{ lib, config, pkgs, ... }:

let
  cfg = config.de;
in
{
  config = lib.mkIf cfg.enable {
    nixpkgs.overlays = [
      (self: super: {
        tor-browser-bundle-bin = super.tor-browser-bundle-bin.overrideAttrs (old: rec {
          version = "10.0.10";
          lang = "en-US";
          src = pkgs.fetchurl {
            url = "https://dist.torproject.org/torbrowser/${version}/tor-browser-linux64-${version}_${lang}.tar.xz";
            sha256 = "vYWZ+NsGN8YH5O61+zrUjlFv3rieaBqjBQ+a18sQcZg=";
          };
        });
      })
    ];

    users.users.googlebot.packages = with pkgs; [
      tor-browser-bundle-bin
    ];
  };
}
