{ config, pkgs, lib, ... }:

# Modify auto-update so that it pulls a flake

let
  cfg = config.system.autoUpgrade;
in
{
  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      system.autoUpgrade = {
        flake = "git+https://git.neet.dev/zuckerberg/nix-config.git";
        flags = [ "--recreate-lock-file" "--no-write-lock-file" ]; # ignore lock file, just pull the latest

        # dates = "03:40";
        # kexecWindow = lib.mkDefault { lower = "01:00"; upper = "05:00"; };
        # randomizedDelaySec = "45min";
      };

      system.autoUpgrade.allowKexec = lib.mkDefault true;

      luks.enableKexec = cfg.allowKexec && builtins.length config.luks.devices > 0;
    }
  ]);
}
