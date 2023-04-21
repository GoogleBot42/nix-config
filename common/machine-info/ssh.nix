{ config, lib, ... }:

let
  machines = config.machines;

  sshkeys = keyType: lib.foldl (l: cfg: l ++ cfg.${keyType}) [ ] (builtins.attrValues machines.hosts);
in
{
  options.machines.ssh = {
    userKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = ''
        List of user keys aggregated from all machines.
      '';
    };

    deployKeys = lib.mkOption {
      default = [ ];
      type = lib.types.listOf lib.types.str;
      description = ''
        List of deploy keys aggregated from all machines.
      '';
    };

    hostKeysByRole = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
      description = ''
        Machine host keys divided into their roles.
      '';
    };
  };

  config = {
    machines.ssh.userKeys = sshkeys "userKeys";
    machines.ssh.deployKeys = sshkeys "deployKeys";

    machines.ssh.hostKeysByRole = lib.mapAttrs
      (role: hosts:
        builtins.map
          (host: machines.hosts.${host}.hostKey)
          hosts)
      machines.roles;
  };
}
