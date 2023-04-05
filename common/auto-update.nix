{ config, lib, ... }:

# Modify auto-update so that it pulls a flake

let
  cfg = config.system.autoUpgrade;
in
{
  config = lib.mkIf cfg.enable {
    system.autoUpgrade = {
      flake = "git+https://git.neet.dev/zuckerberg/nix-config.git";
      flags = [ "--recreate-lock-file" ]; # ignore lock file, just pull the latest
    };
  };
}
