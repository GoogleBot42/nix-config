{ config, lib, pkgs, ... }:

# Incus-specific configuration for sandboxed workspaces
# Creates fully declarative Incus containers from NixOS configurations

with lib;

let
  cfg = config.sandboxed-workspace;
  hostConfig = config;

  incusWorkspaces = filterAttrs (n: ws: ws.type == "incus") cfg.workspaces;

  # Build a NixOS LXC image for a workspace
  mkContainerImage = name: ws:
    let
      nixpkgs = hostConfig.inputs.nixpkgs;
      containerSystem = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit hostConfig; };
        modules = [
          (import ./base.nix {
            inherit hostConfig;
            workspaceName = name;
            ip = ws.ip;
            networkInterface = { Name = "eth0"; };
          })

          (import ws.config)

          ({ config, lib, pkgs, ... }: {
            nixpkgs.hostPlatform = hostConfig.currentSystem;
            boot.isContainer = true;
            networking.useHostResolvConf = false;
            nixpkgs.config.allowUnfree = true;

            # Incus containers don't support the kernel features nix sandbox requires
            nix.settings.sandbox = false;

            hardware.graphics.enable = lib.mkIf ws.passHostGpu true;

            environment.systemPackages = [
              (lib.hiPrio (pkgs.writeShellScriptBin "claude" ''
                exec ${pkgs.claude-code}/bin/claude --dangerously-skip-permissions "$@"
              ''))
            ] ++ lib.optionals ws.passHostGpu [
              pkgs.vulkan-tools
            ];
          })
        ];
      };
    in
    {
      # zstd instead of the default pixz: compresses the multi-GB rootfs in
      # seconds instead of minutes (and incus unpacks it much faster too).
      # The incus daemon ships zstd in its path, so import just works.
      rootfs = containerSystem.config.system.build.images.lxc.override {
        compressCommand = "zstd -T0 -c";
        compressionExtension = ".zst";
        extraInputs = [ pkgs.zstd ];
      };
      metadata = containerSystem.config.system.build.images.lxc-metadata;
      toplevel = containerSystem.config.system.build.toplevel;
    };

  # Evaluate each workspace's guest system once, shared by the systemd
  # service and the sandboxedWorkspaceGuests closure export below.
  workspaceImages = mapAttrs mkContainerImage incusWorkspaces;

  mkIncusService = name: ws:
    let
      images = workspaceImages.${name};
      hash = builtins.substring 0 12 (builtins.hashString "sha256" "${images.rootfs}");
      imageName = "nixos-workspace-${name}-${hash}";
      containerName = "workspace-${name}";

      bridgeName = config.networking.sandbox.bridgeName;
      mac = lib.mkMac "incus-${name}";

      addDevices = ''
        incus config device add ${containerName} eth0 nic nictype=bridged parent=${bridgeName} hwaddr=${mac}
        incus config device add ${containerName} workspace disk source=/home/googlebot/sandboxed/${name}/workspace path=/home/googlebot/workspace shift=true
        incus config device add ${containerName} ssh-keys disk source=/home/googlebot/sandboxed/${name}/ssh-host-keys path=/etc/ssh-host-keys shift=true
        incus config device add ${containerName} claude-config disk source=/home/googlebot/sandboxed/${name}/claude-config path=/home/googlebot/claude-config shift=true
        incus config device add ${containerName} attic-netrc disk source=/run/agenix/attic-netrc path=/etc/attic-netrc shift=false
        ${lib.optionalString ws.passHostGpu ''
          incus config device add ${containerName} gpu gpu
        ''}${lib.concatStrings (lib.mapAttrsToList (mountName: m: ''
          incus config device add ${containerName} ${mountName} disk source=${m.hostPath} path=${m.containerPath} shift=${lib.boolToString m.shift}
        '') ws.extraMounts)}
      '';
    in
    {
      description = "Incus workspace ${name}";
      after = [ "incus.service" "incus-preseed.service" "workspace-${name}-setup.service" ];
      requires = [ "incus.service" ];
      wants = [ "workspace-${name}-setup.service" ];
      wantedBy = optional ws.autoStart "multi-user.target";

      path = [ config.virtualisation.incus.package pkgs.gnutar pkgs.xz pkgs.util-linux ];

      restartTriggers = [ images.rootfs images.metadata ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script = ''
        set -euo pipefail

        # Serialize incus operations - concurrent container creation causes race conditions
        exec 9>/run/incus-workspace.lock
        flock -x 9

        # Import image if not present
        if ! incus image list --format csv | grep -q "${imageName}"; then
          metadata_tarball=$(echo ${images.metadata}/tarball/*.tar.xz)
          rootfs_tarball=$(echo ${images.rootfs}/tarball/*.tar.zst)
          incus image import "$metadata_tarball" "$rootfs_tarball" --alias ${imageName}

          # Clean up old images for this workspace
          incus image list --format csv | grep "nixos-workspace-${name}-" | grep -v "${imageName}" | cut -d, -f2 | while read old_image; do
            incus image delete "$old_image" || true
          done || true
        fi

        # Always recreate container for ephemeral behavior
        incus stop ${containerName} --force 2>/dev/null || true
        incus delete ${containerName} --force 2>/dev/null || true

        incus init ${imageName} ${containerName}
        ${addDevices}
        incus start ${containerName}

        # Wait for container to start
        for i in $(seq 1 30); do
          if incus list --format csv | grep -q "^${containerName},RUNNING"; then
            exit 0
          fi
          sleep 1
        done

        exit 1
      '';

      preStop = ''
        exec 9>/run/incus-workspace.lock
        flock -x 9

        incus stop ${containerName} --force 2>/dev/null || true
        incus delete ${containerName} --force 2>/dev/null || true

        # Clean up all images for this workspace
        incus image list --format csv 2>/dev/null | grep "nixos-workspace-${name}-" | cut -d, -f2 | while read img; do
          incus image delete "$img" 2>/dev/null || true
        done
      '';
    };


in
{
  config = mkIf (cfg.enable && incusWorkspaces != { }) {

    virtualisation.incus.enable = true;
    networking.nftables.enable = true;

    virtualisation.incus.preseed = {
      storage_pools = [{
        name = "default";
        driver = "dir";
        config = {
          source = "/var/lib/incus/storage-pools/default";
        };
      }];

      profiles = [{
        name = "default";
        config = {
          "security.privileged" = "false";
          "security.idmap.isolated" = "true";
        };
        devices = {
          root = {
            path = "/";
            pool = "default";
            type = "disk";
          };
        };
      }];
    };

    systemd.services = mapAttrs'
      (name: ws: nameValuePair "incus-workspace-${name}" (mkIncusService name ws))
      incusWorkspaces;

    # Guest systems are only referenced through the rootfs tarballs, so their
    # store paths never appear in the host closure and would otherwise never
    # reach the binary cache. Export them so CI can push the closures
    # (see .gitea/scripts/build-and-cache.sh).
    system.build.sandboxedWorkspaceGuests = pkgs.linkFarm "sandboxed-workspace-guests"
      (mapAttrsToList (name: images: { inherit name; path = images.toplevel; }) workspaceImages);

    # Extra alias for incus shell access (ssh is also available via default.nix aliases)
    environment.shellAliases = mkMerge (mapAttrsToList
      (name: ws: {
        "workspace_${name}_shell" = "doas incus exec workspace-${name} -- su -l googlebot";
      })
      incusWorkspaces);
  };
}
