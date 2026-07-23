{ config, lib, pkgs, ... }:

# Podman-backed Gitea Actions runner.
#
# This is intentionally separate from the legacy NixOS-container runner. New or
# migrated workflows opt in with `runs-on: nixos-podman`, while existing
# `runs-on: nixos` jobs remain on the legacy runner until deliberately changed.

let
  thisMachineIsARunner = config.thisMachine.hasRole."gitea-actions-runner";
  podmanRunnerInstance = "podman";
  podmanRunnerName = "gitea-runner-podman";
  ubuntuRunnerInstance = "ubuntu";
  ubuntuRunnerName = "gitea-runner-ubuntu";
  runnerImageName = "localhost/gitea-runner-nix";
  runnerImageTag = "latest";

  # Podman job containers share the host kernel's binfmt_misc registrations.
  # With preferStaticEmulators (set below) registrations use the fix-binary
  # flag, so the kernel pins the interpreter at registration time and nothing
  # needs to exist inside the container rootfs. For any registration that has
  # no static emulator (interpreterSandboxPath != null), fall back to baking
  # its interpreter root into the runner image.
  binfmtInterpreterRoots = lib.unique (
    lib.filter (path: path != null) (
      map (registration: registration.interpreterSandboxPath) (
        lib.attrValues config.boot.binfmt.registrations
      )
    )
  );

  runnerImage = pkgs.dockerTools.buildImageWithNixDb {
    name = runnerImageName;
    tag = runnerImageTag;
    copyToRoot = pkgs.buildEnv {
      name = "gitea-runner-image-root";
      pathsToLink = [ "/bin" ];
      paths = (with pkgs; [
        attic-client
        bashInteractive
        cacert
        coreutils
        curl
        findutils
        gawk
        git
        gnugrep
        gnused
        gnutar
        gzip
        jq
        nix
        nodejs
        openssh
        xz
        zstd
      ]) ++ binfmtInterpreterRoots;
    };
    config = {
      Env = [
        "PATH=/bin"
        "USER=root"
        "NIX_PAGER=cat"
        "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
        "NIX_SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
        ("NIX_CONFIG=experimental-features = nix-command flakes\nsandbox = false"
          + lib.optionalString (config.boot.binfmt.emulatedSystems != [ ])
          "\nextra-platforms = ${toString config.boot.binfmt.emulatedSystems}")
      ];
      Cmd = [ "${pkgs.bashInteractive}/bin/bash" ];
    };
  };
in
{
  config = lib.mkIf (thisMachineIsARunner && !config.boot.isContainer) {
    # Register binfmt emulators as static binaries with the fix-binary (F)
    # flag so job containers can exec foreign-arch binaries without the
    # interpreter existing in their rootfs.
    boot.binfmt.preferStaticEmulators = true;

    virtualisation.podman = {
      enable = true;
      dockerSocket.enable = true;
      autoPrune = {
        enable = true;
        flags = [ "--filter=until=168h" ];
      };
    };

    systemd.services.gitea-runner-load-podman-image = {
      description = "Load Gitea Actions Podman runner job image";
      after = [ "podman.socket" ];
      requires = [ "podman.socket" ];
      wantedBy = [ "multi-user.target" ];
      before = [ "gitea-runner-${podmanRunnerInstance}.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      path = [ config.virtualisation.podman.package ];
      script = ''
        set -euo pipefail
        podman load --input ${runnerImage}
        podman image exists ${runnerImageName}:${runnerImageTag}
      '';
    };

    services.gitea-actions-runner.instances.${podmanRunnerInstance} = {
      enable = true;
      name = podmanRunnerName;
      url = "https://git.neet.dev/";
      tokenFile = config.age.secrets.gitea-actions-runner-token.path;
      labels = [ "nixos-podman:docker://${runnerImageName}:${runnerImageTag}" ];
      settings = {
        container = {
          force_pull = false;
          require_docker = true;
          docker_host = "unix:///run/podman/podman.sock";
          # Reuse the host Nix store as a read-only lowerdir with a private
          # per-container writable overlay. Mount all of /nix, not just
          # /nix/store, so the copied-up Nix DB remains consistent with the
          # visible store paths while writes still stay out of the host store.
          options = "--volume /nix:/nix:O";
        };
      };
    };

    systemd.services."gitea-runner-${podmanRunnerInstance}" = {
      requires = [
        "gitea-runner-load-podman-image.service"
        "podman.socket"
      ];
      after = [
        "gitea-runner-load-podman-image.service"
        "podman.socket"
      ];
    };

    # Plain ubuntu-latest runner so unmodified GitHub Actions workflows work.
    # Jobs run in the catthehacker images, which mirror the tooling of
    # GitHub-hosted ubuntu runners. Kept as a separate instance so the
    # nix-specific container options above (host /nix overlay) don't apply
    # to ubuntu jobs.
    services.gitea-actions-runner.instances.${ubuntuRunnerInstance} = {
      enable = true;
      name = ubuntuRunnerName;
      url = "https://git.neet.dev/";
      tokenFile = config.age.secrets.gitea-actions-runner-token.path;
      labels = [
        "ubuntu-latest:docker://ghcr.io/catthehacker/ubuntu:act-latest"
        "ubuntu-24.04:docker://ghcr.io/catthehacker/ubuntu:act-24.04"
        "ubuntu-22.04:docker://ghcr.io/catthehacker/ubuntu:act-22.04"
      ];
      settings.container = {
        # Only pull when the image is missing; images update via autoPrune
        # cycling out old layers rather than pulling on every job.
        force_pull = false;
        require_docker = true;
        docker_host = "unix:///run/podman/podman.sock";
      };
    };

    systemd.services."gitea-runner-${ubuntuRunnerInstance}" = {
      requires = [ "podman.socket" ];
      after = [ "podman.socket" ];
    };
  };
}
