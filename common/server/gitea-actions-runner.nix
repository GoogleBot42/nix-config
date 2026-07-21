{ config, lib, allModules, ... }:

# Gitea Actions runners for git.neet.dev.
#
# Keep the existing NixOS-container runner online while new workflows are moved
# over to the Podman-backed runner explicitly. The old runner keeps the `nixos`
# label; the new runner uses `nixos-podman` so workflow diffs make the migration
# and eventual old-runner removal easy to review.
# To enable, assign a machine the 'gitea-actions-runner' system role.

let
  thisMachineIsARunner = config.thisMachine.hasRole."gitea-actions-runner";
  hostName = config.networking.hostName;
  legacyContainerName = "gitea-runner";
  legacyRunnerUid = 991;
  legacyRunnerGid = 989;
in
{
  imports = [
    ./gitea-actions-runner-podman.nix
  ];

  config = lib.mkIf (thisMachineIsARunner && !config.boot.isContainer) {
    age.secrets.gitea-actions-runner-token.file = ../../secrets/gitea-actions-runner-token.age;

    # Legacy NixOS-container runner. It shares the host's /nix/store (read-only)
    # and nix-daemon socket, so builds go through the host daemon and outputs
    # land in the host store. Keep this path on the existing `nixos` label until
    # workflows are deliberately migrated to the Podman-backed `nixos-podman`
    # runner imported above.
    # Warning: NixOS containers are not fully secure — do not run untrusted code.
    containers.${legacyContainerName} = {
      autoStart = true;
      ephemeral = true;

      bindMounts = {
        "/run/agenix/gitea-actions-runner-token" = {
          hostPath = config.age.secrets.gitea-actions-runner-token.path;
          isReadOnly = true;
        };
        "/var/lib/gitea-runner" = {
          hostPath = "/var/lib/gitea-runner";
          isReadOnly = false;
        };
      };

      config = { config, lib, pkgs, ... }: {
        imports = allModules;

        ntfy-alerts.ignoredUnits = [ "logrotate" ];
        ntfy-alerts.hostLabel = "${hostName}/${legacyContainerName}";

        services.gitea-actions-runner.instances.inst = {
          enable = true;
          name = legacyContainerName;
          url = "https://git.neet.dev/";
          tokenFile = "/run/agenix/gitea-actions-runner-token";
          labels = [ "nixos:host" ];
          # Run up to two jobs at once so a long flake check doesn't queue
          # every other push behind it. Builds share the host nix-daemon,
          # which locks derivations, so overlapping jobs dedupe work.
          settings.runner.capacity = 2;
        };

        # Disable dynamic user so runner state persists via bind mount.
        assertions = [{
          assertion = config.systemd.services.gitea-runner-inst.enable;
          message = "Expected systemd service 'gitea-runner-inst' is not enabled — the gitea-actions-runner module may have changed its naming scheme.";
        }];
        systemd.services.gitea-runner-inst.serviceConfig.DynamicUser = lib.mkForce false;
        users.users.gitea-runner = {
          uid = legacyRunnerUid;
          home = "/var/lib/gitea-runner";
          group = "gitea-runner";
          isSystemUser = true;
          createHome = true;
        };
        users.groups.gitea-runner.gid = legacyRunnerGid;

        nix.settings.experimental-features = [ "nix-command" "flakes" ];

        environment.systemPackages = with pkgs; [
          git
          nodejs
          jq
          attic-client
        ];
      };
    };

    # The legacy container uses the host nix-daemon. Keep the matching host user
    # trusted until all workflows have moved off the `nixos` runner.
    nix.settings.trusted-users = [ "gitea-runner" ];

    users.users.gitea-runner = {
      uid = legacyRunnerUid;
      home = "/var/lib/gitea-runner";
      group = "gitea-runner";
      isSystemUser = true;
      createHome = true;
    };
    users.groups.gitea-runner.gid = legacyRunnerGid;
  };
}
