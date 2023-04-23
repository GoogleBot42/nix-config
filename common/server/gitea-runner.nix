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
    instanceUrl = lib.mkOption {
      type = lib.types.str;
    };
    registrationTokenFile = lib.mkOption {
      type = lib.types.path;
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

    # registration token
    services.gitea-runner.registrationTokenFile = "/run/agenix/gitea-runner-registration-token";
    age.secrets.gitea-runner-registration-token = {
      file = ../../secrets/gitea-runner-registration-token.age;
      owner = "gitea-runner";
    };

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

      # based on https://gitea.com/gitea/act_runner/src/branch/main/run.sh
      script = ''
        . ${cfg.registrationTokenFile}

        if [[ ! -s .runner ]]; then
          try=$((try + 1))
          success=0

          LOGFILE="$(mktemp)"

          # The point of this loop is to make it simple, when running both act_runner and gitea in docker,
          # for the act_runner to wait a moment for gitea to become available before erroring out.  Within
          # the context of a single docker-compose, something similar could be done via healthchecks, but
          # this is more flexible.
          while [[ $success -eq 0 ]] && [[ $try -lt ''${10:-10} ]]; do
            act_runner register \
              --instance "${cfg.instanceUrl}" \
              --token    "$GITEA_RUNNER_REGISTRATION_TOKEN" \
              --name     "${config.networking.hostName}" \
              --no-interactive > $LOGFILE 2>&1

            cat $LOGFILE

            cat $LOGFILE | grep 'Runner registered successfully' > /dev/null
            if [[ $? -eq 0 ]]; then
              echo "SUCCESS"
              success=1
            else
              echo "Waiting to retry ..."
              sleep 5
            fi
          done
        fi

        exec act_runner daemon
      '';
    };
  };
}
