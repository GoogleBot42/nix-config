{ config, lib, ... }:

let
  cfg = config.services.actual;
in
{
  config = lib.mkIf cfg.enable {
    services.actual.settings = {
      port = 25448;
    };

    backup.group."actual-budget".paths = [
      "/var/lib/actual"
    ];
  };
}
