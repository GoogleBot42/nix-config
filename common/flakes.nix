{ lib, config, ... }:
with lib;
let
  cfg = config.nix.flakes;
in
{
  options.nix.flakes = {
    enable = mkEnableOption "use nix flakes";
  };

  config = mkIf cfg.enable {
    nix = {
      extraOptions = ''
        experimental-features = nix-command flakes
      '';
    };
  };
}
