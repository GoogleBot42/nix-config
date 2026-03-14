{ config, lib, ... }:

{
  imports = [
    ./service-failure.nix
    ./ssh-login.nix
    ./zfs.nix
    ./dimm-temp.nix
  ];

  options.ntfy-alerts = {
    serverUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://ntfy.neet.dev";
      description = "Base URL of the ntfy server.";
    };

    curlExtraArgs = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Extra arguments to pass to curl (e.g. --proxy http://host:port).";
    };

    ignoredUnits = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Unit names to skip failure notifications for.";
    };

    hostLabel = lib.mkOption {
      type = lib.types.str;
      default = config.networking.hostName;
      description = "Label used in ntfy alert titles to identify this host/container.";
    };
  };

  config = lib.mkIf config.thisMachine.hasRole."ntfy" {
    age.secrets.ntfy-token.file = ../../secrets/ntfy-token.age;
  };
}
