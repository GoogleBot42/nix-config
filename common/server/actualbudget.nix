{ config, lib, ... }:

let
  cfg = config.services.actual;
in
{
  config = lib.mkIf cfg.enable {
    services.actual.settings = {
      port = 25448;
    };

    # DynamicUser: /var/lib/actual is a symlink, which restic stores as a
    # symlink. Back up the target.
    backup.group."actual-budget".paths = [
      "/var/lib/private/actual"
    ];
  };
}
