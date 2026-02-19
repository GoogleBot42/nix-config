{ config, lib, ... }:

{
  config = lib.mkIf (config.thisMachine.hasRole."binary-cache") {
    services.atticd = {
      enable = true;
      environmentFile = config.age.secrets.atticd-credentials.path;
      settings = {
        listen = "[::]:28338";
        database.url = "postgresql:///atticd?host=/run/postgresql";
        require-proof-of-possession = false;

        # Disable chunking — the dedup savings don't justify the CPU/IO
        # overhead for local storage, especially on ZFS which already
        # does block-level compression.
        chunking = {
          nar-size-threshold = 0;
          min-size = 16 * 1024;
          avg-size = 64 * 1024;
          max-size = 256 * 1024;
        };

        # Let ZFS handle compression instead of double-compressing.
        compression.type = "none";

        garbage-collection.default-retention-period = "6 months";
      };
    };

    # PostgreSQL for atticd
    services.postgresql = {
      enable = true;
      ensureDatabases = [ "atticd" ];
      ensureUsers = [{
        name = "atticd";
        ensureDBOwnership = true;
      }];
    };

    # Use a static user so the ZFS mountpoint at /var/lib/atticd works
    # (DynamicUser conflicts with ZFS mountpoints)
    users.users.atticd = {
      isSystemUser = true;
      group = "atticd";
      home = "/var/lib/atticd";
    };
    users.groups.atticd = { };

    systemd.services.atticd = {
      after = [ "postgresql.service" ];
      requires = [ "postgresql.service" ];
      serviceConfig = {
        DynamicUser = lib.mkForce false;
        User = "atticd";
        Group = "atticd";
      };
    };

    age.secrets.atticd-credentials.file = ../../secrets/atticd-credentials.age;
  };
}
