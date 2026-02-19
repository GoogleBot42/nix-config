{ config, lib, ... }:

# Gitea Actions Runner inside a NixOS container.
# The container shares the host's /nix/store (read-only) and nix-daemon socket,
# so builds go through the host daemon and outputs land in the host store.
# Warning: NixOS containers are not fully secure — do not run untrusted code.
# To enable, assign a machine the 'gitea-actions-runner' system role.

let
  thisMachineIsARunner = config.thisMachine.hasRole."gitea-actions-runner";
  containerName = "gitea-runner";
  giteaRunnerUid = 991;
  giteaRunnerGid = 989;
in
{
  config = lib.mkIf (thisMachineIsARunner && !config.boot.isContainer) {

    containers.${containerName} = {
      autoStart = true;
      ephemeral = true;

      bindMounts = {
        "/run/agenix/gitea-actions-runner-token" = {
          hostPath = "/run/agenix/gitea-actions-runner-token";
          isReadOnly = true;
        };
        "/var/lib/gitea-runner" = {
          hostPath = "/var/lib/gitea-runner";
          isReadOnly = false;
        };
      };

      config = { config, lib, pkgs, ... }: {
        system.stateVersion = "25.11";

        services.gitea-actions-runner.instances.inst = {
          enable = true;
          name = containerName;
          url = "https://git.neet.dev/";
          tokenFile = "/run/agenix/gitea-actions-runner-token";
          labels = [ "nixos:host" ];
        };

        # Disable dynamic user so runner state persists via bind mount
        assertions = [{
          assertion = config.systemd.services.gitea-runner-inst.enable;
          message = "Expected systemd service 'gitea-runner-inst' is not enabled — the gitea-actions-runner module may have changed its naming scheme.";
        }];
        systemd.services.gitea-runner-inst.serviceConfig.DynamicUser = lib.mkForce false;
        users.users.gitea-runner = {
          uid = giteaRunnerUid;
          home = "/var/lib/gitea-runner";
          group = "gitea-runner";
          isSystemUser = true;
          createHome = true;
        };
        users.groups.gitea-runner.gid = giteaRunnerGid;

        nix.settings.experimental-features = [ "nix-command" "flakes" ];

        environment.systemPackages = with pkgs; [
          git
          nodejs
          jq
          attic-client
        ];
      };
    };

    # Needs to be outside of the container because container uses's the host's nix-daemon
    nix.settings.trusted-users = [ "gitea-runner" ];

    # Matching user on host — the container's gitea-runner UID must be
    # recognized by the host's nix-daemon as trusted (shared UID namespace)
    users.users.gitea-runner = {
      uid = giteaRunnerUid;
      home = "/var/lib/gitea-runner";
      group = "gitea-runner";
      isSystemUser = true;
      createHome = true;
    };
    users.groups.gitea-runner.gid = giteaRunnerGid;

    age.secrets.gitea-actions-runner-token.file = ../../secrets/gitea-actions-runner-token.age;
  };
}
