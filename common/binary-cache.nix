{ config, lib, ... }:

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
        "nixos:IDhKojUaMz+UIiri1/DQk9EpqDokih8dwxmp41uJnls="
      ];
    };
  };
}
