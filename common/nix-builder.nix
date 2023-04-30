{ config, lib, ... }:

let
  builderRole = "nix-builder";
  builderUserName = "nix-builder";

  machinesByRole = role: lib.filterAttrs (hostname: cfg: builtins.elem role cfg.systemRoles) config.machines.hosts;
  otherMachinesByRole = role: lib.filterAttrs (hostname: cfg: hostname != config.networking.hostName) (machinesByRole role);
  thisMachineHasRole = role: builtins.hasAttr config.networking.hostName (machinesByRole role);

  builders = machinesByRole builderRole;
  thisMachineIsABuilder = thisMachineHasRole builderRole;

  # builders don't include themselves as a remote builder
  otherBuilders = lib.filterAttrs (hostname: cfg: hostname != config.networking.hostName) builders;
in
lib.mkMerge [
  # configure builder
  (lib.mkIf thisMachineIsABuilder {
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
      (builderCfg: {
        hostName = builtins.elemAt builderCfg.hostNames 0;
        system = builderCfg.arch;
        protocol = "ssh-ng";
        sshUser = builderUserName;
        sshKey = "/etc/ssh/ssh_host_ed25519_key";
        maxJobs = 3;
        speedFactor = 10;
        supportedFeatures = [ "nixos-test" "benchmark" "big-parallel" "kvm" ];
      })
      (builtins.attrValues otherBuilders);

    # It is very likely that the builder's internet is faster or just as fast
    nix.extraOptions = ''
      builders-use-substitutes = true
    '';
  }
]
