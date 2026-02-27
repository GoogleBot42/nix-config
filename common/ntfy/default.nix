{ config, lib, ... }:

{
  imports = [
    ./service-failure.nix
    ./ssh-login.nix
    ./zfs.nix
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
  };

  config = lib.mkIf config.thisMachine.hasRole."ntfy" {
    age.secrets.ntfy-token.file = ../../secrets/ntfy-token.age;
  };
}
