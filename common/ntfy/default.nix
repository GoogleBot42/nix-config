{ config, lib, ... }:

let
  cfg = config.ntfy-alerts;
  repeatedHex = n: lib.concatStrings (lib.replicate n "[0-9a-f]");
  transientContainerUnitPatterns = [
    "${repeatedHex 64}-${repeatedHex 14}.service"
    "${repeatedHex 64}-${repeatedHex 15}.service"
    "${repeatedHex 64}-${repeatedHex 16}.service"
  ];
in
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

    ignoredUnitPatterns = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Shell glob unit name patterns to skip failure notifications for.";
    };

    ignoreTransientContainerUnitFailures = lib.mkEnableOption "ignoring generated transient Podman/container unit failures";

    hostLabel = lib.mkOption {
      type = lib.types.str;
      default = config.networking.hostName;
      description = "Label used in ntfy alert titles to identify this host/container.";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf config.thisMachine.hasRole."ntfy" {
      age.secrets.ntfy-token.file = ../../secrets/ntfy-token.age;
    })

    (lib.mkIf cfg.ignoreTransientContainerUnitFailures {
      ntfy-alerts.ignoredUnitPatterns = transientContainerUnitPatterns;
    })
  ];
}
