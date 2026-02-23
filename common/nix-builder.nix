{ config, lib, ... }:

let
  builderUserName = "nix-builder";

  builderRole = "nix-builder";
  builders = config.machines.withRole.${builderRole} or [];
  thisMachineIsABuilder = config.thisMachine.hasRole.${builderRole} or false;

  # builders don't include themselves as a remote builder
  otherBuilders = lib.filter (hostname: hostname != config.networking.hostName) builders;
in
lib.mkMerge [
  # configure builder
  (lib.mkIf (thisMachineIsABuilder && !config.boot.isContainer) {
    users.users.${builderUserName} = {
      description = "Distributed Nix Build User";
      group = builderUserName;
      isSystemUser = true;
      createHome = true;
      home = "/var/lib/nix-builder";
      useDefaultShell = true;
      openssh.authorizedKeys.keys = builtins.map
        (builderCfg: builderCfg.hostKey)
        (builtins.attrValues config.machines.hosts);
    };
    users.groups.${builderUserName} = { };

    nix.settings.trusted-users = [
      builderUserName
    ];
  })

  # use each builder
  {
    nix.distributedBuilds = true;

    nix.buildMachines = builtins.map
      (builderHostname: {
        hostName = builderHostname;
        system = config.machines.hosts.${builderHostname}.arch;
        protocol = "ssh-ng";
        sshUser = builderUserName;
        sshKey = "/etc/ssh/ssh_host_ed25519_key";
        maxJobs = 3;
        speedFactor = 10;
        supportedFeatures = [ "nixos-test" "benchmark" "big-parallel" "kvm" ];
      })
      otherBuilders;

    # It is very likely that the builder's internet is faster or just as fast
    nix.extraOptions = ''
      builders-use-substitutes = true
    '';
  }
]
