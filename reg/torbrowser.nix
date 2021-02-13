{ config, pkgs, ... }:

{
#  nixpkgs.config.packageOverrides = pkgs: {
#    tor-browser-bundle-bin = pkgs.tor-browser-bundle-bin.overrideAttrs (old: {
#      version = "10.0.10";
#      src = builtins.fetchurl {
#        url = "https://dist.torproject.org/torbrowser/10.0.10/tor-browser-linux64-10.0.10_en-US.tar.xz";
#        sha256 = "vYWZ+NsGN8YH5O61+zrUjlFv3rieaBqjBQ+a18sQcZg=";
#      };
#    });
#  };
#
#  nixpkgs.overlays = [ (
#  self: super:
#  {
#    tor-browser-bundle-bin = super.tor-browser-bundle-bin.overrideAttrs (old: {
#      version = "10.0.10";
#      lang = "en-US";
#      src = super.fetchurl {
#        url = "https://dist.torproject.org/torbrowser/10.0.10/tor-browser-linux64-10.0.10_en-US.tar.xz";
#        sha256 = "vYWZ+NsGN8YH5O61+zrUjlFv3rieaBqjBQ+a18sQcZg=";
#      };
#    });
#  }
#  ) ];  
}
