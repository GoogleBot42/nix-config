{ config, lib, pkgs, ... }:

# Unified sandboxed workspace module supporting both VMs and containers
# This module provides isolated development environments with shared configuration

with lib;

let
  cfg = config.sandboxed-workspace;
in
{
  imports = [
    ./vm.nix
    ./container.nix
  ];

  options.sandboxed-workspace = {
    enable = mkEnableOption "sandboxed workspace management";

    workspaces = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          type = mkOption {
            type = types.enum [ "vm" "container" ];
            description = ''
              Backend type for this workspace:
              - "vm": microVM with cloud-hypervisor (more isolation, uses virtiofs)
              - "container": systemd-nspawn container (less overhead, uses bind mounts)
            '';
          };

          config = mkOption {
            type = types.path;
            description = "Path to the workspace configuration file";
          };

          ip = mkOption {
            type = types.str;
            example = "192.168.83.10";
            description = ''
              Static IP address for this workspace on the microvm bridge network.
              Configures the workspace's network interface and adds an entry to /etc/hosts
              on the host so the workspace can be accessed by name (e.g., ssh workspace-example).
              Must be in the 192.168.83.0/24 subnet (or whatever networking.sandbox.subnet is).
            '';
          };

          hostKey = mkOption {
            type = types.nullOr types.str;
            default = null;
            example = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA...";
            description = ''
              SSH host public key for this workspace. If set, adds to programs.ssh.knownHosts
              so the host automatically trusts the workspace without prompting.
              Get the key from: ~/sandboxed/<name>/ssh-host-keys/ssh_host_ed25519_key.pub
            '';
          };

          autoStart = mkOption {
            type = types.bool;
            default = false;
            description = "Whether to automatically start this workspace on boot";
          };

          cid = mkOption {
            type = types.nullOr types.int;
            default = null;
            description = ''
              vsock Context Identifier for this workspace (VM-only, ignored for containers).
              If null, auto-generated from workspace name.
              Must be unique per host. Valid range: 3 to 4294967294.
              See: https://man7.org/linux/man-pages/man7/vsock.7.html
            '';
          };
        };
      });
      default = { };
      description = "Sandboxed workspace configurations";
    };
  };

  config = mkIf cfg.enable {
    # Automatically enable sandbox networking when workspaces are defined
    networking.sandbox.enable = mkIf (cfg.workspaces != { }) true;

    # Add workspace hostnames to /etc/hosts so they can be accessed by name
    networking.hosts = lib.mkMerge (lib.mapAttrsToList
      (name: ws: {
        ${ws.ip} = [ "workspace-${name}" ];
      })
      cfg.workspaces);

    # Add workspace SSH host keys to known_hosts so host trusts workspaces without prompting
    programs.ssh.knownHosts = lib.mkMerge (lib.mapAttrsToList
      (name: ws:
        lib.optionalAttrs (ws.hostKey != null) {
          "workspace-${name}" = {
            publicKey = ws.hostKey;
            extraHostNames = [ ws.ip ];
          };
        })
      cfg.workspaces);

    # Shell aliases for workspace management
    # Service names differ by type: microvm@<name> for VMs, container@<name> for containers
    environment.shellAliases = lib.mkMerge (lib.mapAttrsToList
      (name: ws:
        let
          serviceName = if ws.type == "vm" then "microvm@${name}" else "container@${name}";
        in
        {
          "workspace_${name}" = "ssh googlebot@workspace-${name}";
          "workspace_${name}_start" = "doas systemctl start ${serviceName}";
          "workspace_${name}_stop" = "doas systemctl stop ${serviceName}";
          "workspace_${name}_restart" = "doas systemctl restart ${serviceName}";
          "workspace_${name}_status" = "doas systemctl status ${serviceName}";
        })
      cfg.workspaces);

    # Automatically generate SSH host keys and directories for all workspaces
    systemd.services = lib.mapAttrs'
      (name: ws:
        let
          serviceName = if ws.type == "vm" then "microvm@${name}" else "container@${name}";
        in
        lib.nameValuePair "workspace-${name}-setup" {
          description = "Setup directories and SSH keys for workspace ${name}";
          wantedBy = [ "multi-user.target" ];
          before = [ "${serviceName}.service" ];

          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };

          script = ''
            # Create directories if they don't exist
            mkdir -p /home/googlebot/sandboxed/${name}/workspace
            mkdir -p /home/googlebot/sandboxed/${name}/ssh-host-keys
            mkdir -p /home/googlebot/sandboxed/${name}/claude-config

            # Fix ownership
            chown -R googlebot:users /home/googlebot/sandboxed/${name}

            # Generate SSH host key if it doesn't exist
            if [ ! -f /home/googlebot/sandboxed/${name}/ssh-host-keys/ssh_host_ed25519_key ]; then
              ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -N "" \
                -f /home/googlebot/sandboxed/${name}/ssh-host-keys/ssh_host_ed25519_key
              chown googlebot:users /home/googlebot/sandboxed/${name}/ssh-host-keys/ssh_host_ed25519_key*
              echo "Generated SSH host key for workspace ${name}"
            fi
          '';
        }
      )
      cfg.workspaces;
  };
}
