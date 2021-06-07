{ lib, pkgs, config, inputs, ... }:
with lib;
let
  cfg = config.nix.flakes;
in {
  options.nix.flakes = {
    enable = mkEnableOption "use nix flakes";
  };

  config = mkIf cfg.enable {
    nix = {
      package = pkgs.nixFlakes;
      extraOptions = ''
        experimental-features = nix-command flakes
      '';

      # pin nixpkgs for system commands such as "nix shell"
      #registry.nixpkgs.flake = inputs.nixpkgs;
    };
  };
}
