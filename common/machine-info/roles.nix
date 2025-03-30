{ config, lib, ... }:

# Maps roles to their hosts.
# machines.withRole = {
#   personal = [
#     "machine1" "machine3"
#   ];
#   cache = [
#     "machine2"
#   ];
# };
#
# A list of all possible roles
# machines.allRoles = [
#   "personal"
#   "cache"
# ];
#
# For each role has true or false if the current machine has that role
# thisMachine.hasRole = {
#   personal = true;
#   cache = false;
# };

{
  options.machines.withRole = lib.mkOption {
    type = lib.types.attrsOf (lib.types.listOf lib.types.str);
  };

  options.machines.allRoles = lib.mkOption {
    type = lib.types.listOf lib.types.str;
  };

  options.thisMachine.hasRole = lib.mkOption {
    type = lib.types.attrsOf lib.types.bool;
  };

  config = {
    machines.withRole = lib.zipAttrs
      (lib.mapAttrsToList
        (host: cfg:
          lib.foldl (lib.mergeAttrs) { }
            (builtins.map (role: { ${role} = host; })
              cfg.systemRoles))
        config.machines.hosts);

    machines.allRoles = lib.attrNames config.machines.withRole;

    thisMachine.hasRole = lib.mapAttrs
      (role: cfg:
        builtins.elem config.networking.hostName config.machines.withRole.${role}
      )
      config.machines.withRole;
  };
}
