{ config, pkgs, lib, ... }:

let
  cfg = config.services.gitea-runner;
in
{
  options.services.gitea-runner = {
    enable = lib.mkEnableOption "Enables gitea runner";
    dataDir = lib.mkOption {
      default = "/var/lib/gitea-runner";
      type = lib.types.str;
      description = lib.mdDoc "gitea runner data directory.";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.docker.enable = true;

    users.users.gitea-runner = {
      description = "Gitea Runner Service";
      home = cfg.dataDir;
      useDefaultShell = true;
      group = "gitea-runner";
      isSystemUser = true;
      createHome = true;
      extraGroups = [
        "docker" # allow creating docker containers
      ];
    };
    users.groups.gitea-runner = { };

    systemd.services.gitea-runner = {
      description = "Gitea Runner";

      serviceConfig = {
        WorkingDirectory = cfg.dataDir;
        User = "gitea-runner";
        Group = "gitea-runner";
      };

      requires = [ "network-online.target" ];
      after = [ "network.target" "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      path = with pkgs; [ gitea-actions-runner ];

      script = ''
        exec act_runner daemon
      '';
    };
  };
}
