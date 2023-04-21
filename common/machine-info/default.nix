# Gathers info about each machine to constuct overall configuration
# Ex: Each machine already trusts each others SSH fingerprint already

{ config, lib, pkgs, ... }:

let
  machines = config.machines.hosts;
in
{
  imports = [
    ./ssh.nix
    ./roles.nix
  ];

  options.machines.hosts = lib.mkOption {
    type = lib.types.attrsOf
      (lib.types.submodule {
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
      });
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
          lib.foldl (lib.mergeAttrs) { } (propertiesFiles' dir "");
        propertiesFiles' = dir: dirName:
          let
            dirContents = builtins.readDir dir;
            dirPaths = lib.filter (path: dirContents.${path} == "directory") (lib.attrNames dirContents);
            propFiles = builtins.map (p: "${dir}/${p}") (lib.filter (path: path == "properties.nix") (lib.attrNames dirContents));
          in
          lib.concatMap (d: propertiesFiles' "${dir}/${d}" d) dirPaths ++ builtins.map (p: { "${dirName}" = p; }) propFiles;
      in
      properties ../../machines;
  };
}
