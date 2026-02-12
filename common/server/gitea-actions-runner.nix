{ config, pkgs, lib, ... }:

# Gitea Actions Runner. Starts 'host' runner that runs directly on the host inside of a nixos container
# This is useful for providing a real Nix/OS builder to gitea.
# Warning, NixOS containers are not secure. For example, the container shares the /nix/store
# Therefore, this should not be used to run untrusted code.
# To enable, assign a machine the 'gitea-actions-runner' system role

# TODO: skipping running inside of nixos container for now because of issues getting docker/podman running

let
  thisMachineIsARunner = config.thisMachine.hasRole."gitea-actions-runner";
  containerName = "gitea-runner";
in
{
  config = lib.mkIf (thisMachineIsARunner && !config.boot.isContainer) {
    # containers.${containerName} = {
    #   ephemeral = true;
    #   autoStart = true;

    #   # for podman
    #   enableTun = true;

    #   # privateNetwork = true;
    #   # hostAddress = "172.16.101.1";
    #   # localAddress = "172.16.101.2";

    #   bindMounts =
    #     {
    #       "/run/agenix/gitea-actions-runner-token" = {
    #         hostPath = "/run/agenix/gitea-actions-runner-token";
    #         isReadOnly = true;
    #       };
    #       "/var/lib/gitea-runner" = {
    #         hostPath = "/var/lib/gitea-runner";
    #         isReadOnly = false;
    #       };
    #     };

    #   extraFlags = [
    #     # Allow podman
    #     ''--system-call-filter=thisystemcalldoesnotexistforsure''
    #   ];

    #   additionalCapabilities = [
    #     "CAP_SYS_ADMIN"
    #   ];

    #   config = {
    #     imports = allModules;

    #     # speeds up evaluation
    #     nixpkgs.pkgs = pkgs;

    #     networking.hostName = lib.mkForce containerName;

    #     # don't use remote builders
    #     nix.distributedBuilds = lib.mkForce false;

    #     environment.systemPackages = with pkgs; [
    #       git
    #       # Gitea Actions rely heavily on node. Include it because it would be installed anyway.
    #       nodejs
    #     ];

    #     services.gitea-actions-runner.instances.inst = {
    #       enable = true;
    #       name = config.networking.hostName;
    #       url = "https://git.neet.dev/";
    #       tokenFile = "/run/agenix/gitea-actions-runner-token";
    #       labels = [
    #         "ubuntu-latest:docker://node:18-bullseye"
    #         "nixos:host"
    #       ];
    #     };

    #     # To allow building on the host, must override the the service's config so it doesn't use a dynamic user
    #     systemd.services.gitea-runner-inst.serviceConfig.DynamicUser = lib.mkForce false;
    #     users.users.gitea-runner = {
    #       home = "/var/lib/gitea-runner";
    #       group = "gitea-runner";
    #       isSystemUser = true;
    #       createHome = true;
    #     };
    #     users.groups.gitea-runner = { };

    #     virtualisation.podman.enable = true;
    #     boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
    #   };
    # };

    # networking.nat.enable = true;
    # networking.nat.internalInterfaces = [
    #   "ve-${containerName}"
    # ];
    # networking.ip_forward = true;

    # don't use remote builders
    nix.distributedBuilds = lib.mkForce false;

    services.gitea-actions-runner.instances.inst = {
      enable = true;
      name = config.networking.hostName;
      url = "https://git.neet.dev/";
      tokenFile = "/run/agenix/gitea-actions-runner-token";
      labels = [
        "ubuntu-latest:docker://node:18-bullseye"
        "nixos:host"
      ];
    };

    environment.systemPackages = with pkgs; [
      git
      # Gitea Actions rely heavily on node. Include it because it would be installed anyway.
      nodejs
    ];

    # To allow building on the host, must override the the service's config so it doesn't use a dynamic user
    systemd.services.gitea-runner-inst.serviceConfig.DynamicUser = lib.mkForce false;
    users.users.gitea-runner = {
      home = "/var/lib/gitea-runner";
      group = "gitea-runner";
      isSystemUser = true;
      createHome = true;
    };
    users.groups.gitea-runner = { };

    virtualisation.podman.enable = true;
    boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

    age.secrets.gitea-actions-runner-token.file = ../../secrets/gitea-actions-runner-token.age;
  };
}
