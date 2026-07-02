{ config, lib, pkgs, ... }:

# Container-specific configuration for sandboxed workspaces using systemd-nspawn
# This module is imported by default.nix for workspaces with type = "container"

with lib;

let
  cfg = config.sandboxed-workspace;
  hostConfig = config;

  # Filter for container-type workspaces only
  containerWorkspaces = filterAttrs (n: ws: ws.type == "container") cfg.workspaces;
in
{
  config = mkIf (cfg.enable && containerWorkspaces != { }) {
    # NixOS container module only sets restartIfChanged when autoStart=true
    # Work around this by setting it directly on the systemd service
    systemd.services = mapAttrs'
      (name: ws: nameValuePair "container@${name}" {
        restartIfChanged = lib.mkForce true;
        restartTriggers = [
          config.containers.${name}.path
          config.environment.etc."nixos-containers/${name}.conf".source
        ];
      })
      containerWorkspaces;

    # Convert container workspace configs to NixOS containers format
    containers = mapAttrs
      (name: ws: {
        autoStart = ws.autoStart;
        privateNetwork = true;
        ephemeral = true;
        restartIfChanged = true;

        # User-namespace the container. Without this, googlebot inside the
        # container is uid 1000 on the host, and nspawn always bind-mounts the
        # host's nix daemon socket (/nix/var/nix/daemon-socket) into the guest.
        # The host daemon trusts uid 1000 (nix.settings.trusted-users), and
        # trusted nix users are root-equivalent - i.e. the sandbox could
        # trivially escalate to host root. With "pick", guest uids map to an
        # unused high range, so the daemon treats workspace processes as
        # untrusted clients (normal nix builds still work).
        privateUsers = "pick";

        # Attach container's veth to the sandbox bridge
        # This creates the veth pair and attaches host side to the bridge
        hostBridge = config.networking.sandbox.bridgeName;

        # Workspace mounts are passed as raw nspawn flags instead of
        # bindMounts because the NixOS module doesn't support the idmap mount
        # option, which is required for host-owned files to show up as
        # googlebot inside the user namespace.
        extraFlags = [
          "--bind=/home/googlebot/sandboxed/${name}/workspace:/home/googlebot/workspace:idmap"
          "--bind=/home/googlebot/sandboxed/${name}/ssh-host-keys:/etc/ssh-host-keys:idmap"
          "--bind=/home/googlebot/sandboxed/${name}/claude-config:/home/googlebot/claude-config:idmap"
        ];

        config = { config, lib, pkgs, ... }: {
          imports = [
            (import ./base.nix {
              inherit hostConfig;
              workspaceName = name;
              ip = ws.ip;
              networkInterface = { Name = "eth0"; };
            })
            (import ws.config)
          ];

          networking.useHostResolvConf = false;

          nixpkgs.config.allowUnfree = true;
        };
      })
      containerWorkspaces;
  };
}
