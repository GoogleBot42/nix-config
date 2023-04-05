{ lib, config, pkgs, ... }:

let
  cfg = config.de;
in
{
  config = lib.mkIf cfg.enable {
    # yubikey
    services.pcscd.enable = true;
    services.udev.packages = [ pkgs.yubikey-personalization ];
  };
}
