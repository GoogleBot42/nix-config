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

        # Attach container's veth to the sandbox bridge
        # This creates the veth pair and attaches host side to the bridge
        hostBridge = config.networking.sandbox.bridgeName;

        bindMounts = {
          "/home/googlebot/workspace" = {
            hostPath = "/home/googlebot/sandboxed/${name}/workspace";
            isReadOnly = false;
          };
          "/etc/ssh-host-keys" = {
            hostPath = "/home/googlebot/sandboxed/${name}/ssh-host-keys";
            isReadOnly = false;
          };
          "/home/googlebot/claude-config" = {
            hostPath = "/home/googlebot/sandboxed/${name}/claude-config";
            isReadOnly = false;
          };
        };

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
