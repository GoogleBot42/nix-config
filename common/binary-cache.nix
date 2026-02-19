{ config, ... }:

{
  nix = {
    settings = {
      substituters = [
        "https://cache.nixos.org/"
        "https://nix-community.cachix.org"
        "http://s0.koi-bebop.ts.net:28338/nixos"
      ];
      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "nixos:e5AMCUWWEX9MESWAAMjBkZdGUpl588NhgsUO3HsdhFw="
      ];

      # Allow substituters to be offline
      # This isn't exactly ideal since it would be best if I could set up a system
      # so that it is an error if a derivation isn't available for any substituters
      # and use this flag as intended for deciding if it should build missing
      # derivations locally. See https://github.com/NixOS/nix/issues/6901
      fallback = true;

      # Authenticate to private nixos cache
      netrc-file = config.age.secrets.attic-netrc.path;
    };
  };

  age.secrets.attic-netrc.file = ../secrets/attic-netrc.age;
}
