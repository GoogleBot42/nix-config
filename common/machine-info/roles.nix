{ config, lib, ... }:

# Maps roles to their hosts

{
  options.machines.roles = lib.mkOption {
    type = lib.types.attrsOf (lib.types.listOf lib.types.str);
  };

  config = {
    machines.roles = lib.zipAttrs
      (lib.mapAttrsToList
        (host: cfg:
          lib.foldl (lib.mergeAttrs) { }
            (builtins.map (role: { ${role} = host; })
              cfg.systemRoles))
        config.machines.hosts);
  };
}
