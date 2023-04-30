{ config, lib, ... }:

{
  nix = {
    settings = {
      substituters = [
        "http://s0.koi-bebop.ts.net:5000"
        "https://nix-community.cachix.org"
        "https://cache.nixos.org/"
      ];
      trusted-public-keys = [
        "s0.koi-bebop.ts.net:OjbzD86YjyJZpCp9RWaQKANaflcpKhtzBMNP8I2aPUU="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    };
  };
}
