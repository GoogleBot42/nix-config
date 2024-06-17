{ config, lib, ... }:

let
  cfg = config.services.atticd;
in
{
  config = lib.mkIf cfg.enable {
    services.atticd = {
      credentialsFile = "/run/agenix/atticd-credentials";

      settings = {
        listen = "[::]:28338";

        chunking = {
          # Disable chunking for performance (I have plenty of space)
          nar-size-threshold = 0;

          # Chunking is disabled due to poor performance so these values don't matter but are required anyway.
          # One day, when I move away from ZFS maybe this will perform well enough.
          # nar-size-threshold = 64 * 1024; # 64 KiB
          min-size = 16 * 1024; # 16 KiB
          avg-size = 64 * 1024; # 64 KiB
          max-size = 256 * 1024; # 256 KiB
        };

        # Disable compression for performance (I have plenty of space)
        compression.type = "none";

        garbage-collection = {
          default-retention-period = "6 months";
        };
      };
    };

    age.secrets.atticd-credentials.file = ../../secrets/atticd-credentials.age;
  };
}
