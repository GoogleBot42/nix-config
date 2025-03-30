# Gathers info about each machine to constuct overall configuration
# Ex: Each machine already trusts each others SSH fingerprint already

{ config, lib, pkgs, ... }:

let
  machines = config.machines.hosts;

  hostOptionsSubmoduleType = lib.types.submodule {
    options = {
      hostNames = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = ''
          List of hostnames for this machine. The first one is the default so it is the target of deployments.
          Used for automatically trusting hosts for ssh connections.
        '';
      };
      arch = lib.mkOption {
        type = lib.types.enum [ "x86_64-linux" "aarch64-linux" ];
        description = ''
          The architecture of this machine.
        '';
      };
      systemRoles = lib.mkOption {
        type = lib.types.listOf lib.types.str; # TODO: maybe use an enum?
        description = ''
          The set of roles this machine holds. Affects secrets available. (TODO add service config as well using this info)
        '';
      };
      hostKey = lib.mkOption {
        type = lib.types.str;
        description = ''
          The system ssh host key of this machine. Used for automatically trusting hosts for ssh connections
          and for decrypting secrets with agenix.
        '';
      };
      remoteUnlock = lib.mkOption {
        default = null;
        type = lib.types.nullOr (lib.types.submodule {
          options = {

            hostKey = lib.mkOption {
              type = lib.types.str;
              description = ''
                The system ssh host key of this machine used for luks boot unlocking only.
              '';
            };

            clearnetHost = lib.mkOption {
              default = null;
              type = lib.types.nullOr lib.types.str;
              description = ''
                The hostname resolvable over clearnet used to luks boot unlock this machine
              '';
            };

            onionHost = lib.mkOption {
              default = null;
              type = lib.types.nullOr lib.types.str;
              description = ''
                The hostname resolvable over tor used to luks boot unlock this machine
              '';
            };

          };
        });
      };
      userKeys = lib.mkOption {
        default = [ ];
        type = lib.types.listOf lib.types.str;
        description = ''
          The list of user keys. Each key here can be used to log into all other systems as `googlebot`.

          TODO: consider auto populating other programs that use ssh keys such as gitea
        '';
      };
      deployKeys = lib.mkOption {
        default = [ ];
        type = lib.types.listOf lib.types.str;
        description = ''
          The list of deployment keys. Each key here can be used to log into all other systems as `root`.
        '';
      };
      configurationPath = lib.mkOption {
        type = lib.types.path;
        description = ''
          The path to this machine's configuration directory.
        '';
      };
    };
  };
in
{
  imports = [
    ./ssh.nix
    ./roles.nix
  ];

  options.machines = {
    hosts = lib.mkOption {
      type = lib.types.attrsOf hostOptionsSubmoduleType;
    };
  };

  options.thisMachine.config = lib.mkOption {
    # For ease of use, a direct copy of the host config from machines.hosts.${hostName}
    type = hostOptionsSubmoduleType;
  };

  config = {
    assertions = (lib.concatLists (lib.mapAttrsToList
      (
        name: cfg: [
          {
            assertion = builtins.length cfg.hostNames > 0;
            message = ''
              Error with config for ${name}
              There must be at least one hostname.
            '';
          }
          {
            assertion = builtins.length cfg.systemRoles > 0;
            message = ''
              Error with config for ${name}
              There must be at least one system role.
            '';
          }
          {
            assertion = cfg.remoteUnlock == null || cfg.remoteUnlock.hostKey != cfg.hostKey;
            message = ''
              Error with config for ${name}
              Unlock hostkey and hostkey cannot be the same because unlock hostkey is in /boot, unencrypted.
            '';
          }
          {
            assertion = cfg.remoteUnlock == null || (cfg.remoteUnlock.clearnetHost != null || cfg.remoteUnlock.onionHost != null);
            message = ''
              Error with config for ${name}
              At least one of clearnet host or onion host must be defined.
            '';
          }
          {
            assertion = cfg.remoteUnlock == null || cfg.remoteUnlock.clearnetHost == null || builtins.elem cfg.remoteUnlock.clearnetHost cfg.hostNames == false;
            message = ''
              Error with config for ${name}
              Clearnet unlock hostname cannot be in the list of hostnames for security reasons.
            '';
          }
          {
            assertion = cfg.remoteUnlock == null || cfg.remoteUnlock.onionHost == null || lib.strings.hasSuffix ".onion" cfg.remoteUnlock.onionHost;
            message = ''
              Error with config for ${name}
              Tor unlock hostname must be an onion address.
            '';
          }
          {
            assertion = builtins.elem "personal" cfg.systemRoles || builtins.length cfg.userKeys == 0;
            message = ''
              Error with config for ${name}
              There must be at least one userkey defined for personal machines.
            '';
          }
          {
            assertion = builtins.elem "deploy" cfg.systemRoles || builtins.length cfg.deployKeys == 0;
            message = ''
              Error with config for ${name}
              Only deploy machines are allowed to have deploy keys for security reasons.
            '';
          }
        ]
      )
      machines));

    # Set per machine properties automatically using each of their `properties.nix` files respectively
    machines.hosts =
      let
        properties = dir: lib.concatMapAttrs
          (name: path: {
            ${name} =
              import path
              //
              { configurationPath = builtins.dirOf path; };
          })
          (propertiesFiles dir);
        propertiesFiles = dir:
          lib.foldl (lib.mergeAttrs) { } (propertiesFiles' dir);
        propertiesFiles' = dir:
          let
            propFiles = lib.filter (p: baseNameOf p == "properties.nix") (lib.filesystem.listFilesRecursive dir);
            dirName = path: builtins.baseNameOf (builtins.dirOf path);
          in
          builtins.map (p: { "${dirName p}" = p; }) propFiles;
      in
      properties ../../machines;

    # Don't try to evaluate "thisMachine" when reflecting using moduleless.nix.
    # When evaluated by moduleless.nix this will fail due to networking.hostName not
    # existing. This is because moduleless.nix is not intended for reflection from the
    # perspective of a perticular machine but is instead intended for reflecting on
    # the properties of all machines as a whole system.
    thisMachine.config = config.machines.hosts.${config.networking.hostName};
  };
}
