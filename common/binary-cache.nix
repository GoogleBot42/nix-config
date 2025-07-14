{ config, lib, ... }:

{
  nix = {
    settings = {
      substituters = [
        "https://cache.nixos.org/"
        "https://nix-community.cachix.org"
        "http://s0.koi-bebop.ts.net:5000"
      ];
      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "s0.koi-bebop.ts.net:OjbzD86YjyJZpCp9RWaQKANaflcpKhtzBMNP8I2aPUU="
      ];

      # Allow substituters to be offline
      # This isn't exactly ideal since it would be best if I could set up a system
      # so that it is an error if a derivation isn't available for any substituters
      # and use this flag as intended for deciding if it should build missing
      # derivations locally. See https://github.com/NixOS/nix/issues/6901
      fallback = true;
    };
  };
}
