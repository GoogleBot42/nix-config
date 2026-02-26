{ config, lib, pkgs, ... }:

# VM-specific configuration for sandboxed workspaces using microvm.nix
# This module is imported by default.nix for workspaces with type = "vm"

with lib;

let
  cfg = config.sandboxed-workspace;
  hostConfig = config;

  # Generate a deterministic vsock CID from workspace name.
  #
  # vsock (virtual sockets) enables host-VM communication without networking.
  # cloud-hypervisor uses vsock for systemd-notify integration: when a VM finishes
  # booting, systemd sends READY=1 to the host via vsock, allowing the host's
  # microvm@ service to accurately track VM boot status instead of guessing.
  #
  # Each VM needs a unique CID (Context Identifier). Reserved CIDs per vsock(7):
  #   - VMADDR_CID_HYPERVISOR (0): reserved for hypervisor
  #   - VMADDR_CID_LOCAL (1): loopback address
  #   - VMADDR_CID_HOST (2): host address
  # See: https://man7.org/linux/man-pages/man7/vsock.7.html
  #      https://docs.kernel.org/virt/kvm/vsock.html
  #
  # We auto-generate from SHA256 hash to ensure uniqueness without manual assignment.
  # Range: 100 - 16777315 (offset avoids reserved CIDs and leaves 3-99 for manual use)
  nameToCid = name:
    let
      hash = builtins.hashString "sha256" name;
      hexPart = builtins.substring 0 6 hash;
    in
    100 + (builtins.foldl'
      (acc: c: acc * 16 + (
        if c == "a" then 10
        else if c == "b" then 11
        else if c == "c" then 12
        else if c == "d" then 13
        else if c == "e" then 14
        else if c == "f" then 15
        else lib.strings.toInt c
      )) 0
      (lib.stringToCharacters hexPart));

  # Filter for VM-type workspaces only
  vmWorkspaces = filterAttrs (n: ws: ws.type == "vm") cfg.workspaces;

  # Generate VM configuration for a workspace
  mkVmConfig = name: ws: {
    inherit pkgs;  # Use host's pkgs (includes allowUnfree)
    config = import ws.config;
    specialArgs = { inputs = hostConfig.inputs; };
    extraModules = [
      (import ./base.nix {
        inherit hostConfig;
        workspaceName = name;
        ip = ws.ip;
        networkInterface = { Type = "ether"; };
      })
      {
        environment.systemPackages = [
          (lib.hiPrio (pkgs.writeShellScriptBin "claude" ''
            exec ${pkgs.claude-code}/bin/claude --dangerously-skip-permissions "$@"
          ''))
        ];

        # MicroVM specific configuration
        microvm = {
          # Use cloud-hypervisor for better performance
          hypervisor = lib.mkDefault "cloud-hypervisor";

          # Resource allocation
          vcpu = 8;
          mem = 4096; # 4GB RAM

          # Disk for writable overlay
          volumes = [{
            image = "overlay.img";
            mountPoint = "/nix/.rw-store";
            size = 8192; # 8GB
          }];

          # Shared directories with host using virtiofs
          shares = [
            {
              # Share the host's /nix/store for accessing packages
              proto = "virtiofs";
              tag = "ro-store";
              source = "/nix/store";
              mountPoint = "/nix/.ro-store";
            }
            {
              proto = "virtiofs";
              tag = "workspace";
              source = "/home/googlebot/sandboxed/${name}/workspace";
              mountPoint = "/home/googlebot/workspace";
            }
            {
              proto = "virtiofs";
              tag = "ssh-host-keys";
              source = "/home/googlebot/sandboxed/${name}/ssh-host-keys";
              mountPoint = "/etc/ssh-host-keys";
            }
            {
              proto = "virtiofs";
              tag = "claude-config";
              source = "/home/googlebot/sandboxed/${name}/claude-config";
              mountPoint = "/home/googlebot/claude-config";
            }
          ];

          # Writeable overlay for /nix/store
          writableStoreOverlay = "/nix/.rw-store";

          # TAP interface for bridged networking
          # The interface name "vm-*" matches the pattern in common/network/microvm.nix
          # which automatically attaches it to the microbr bridge
          interfaces = [{
            type = "tap";
            id = "vm-${name}";
            mac = lib.mkMac "vm-${name}";
          }];

          # Enable vsock for systemd-notify integration
          vsock.cid =
            if ws.cid != null
            then ws.cid
            else nameToCid name;
        };
      }
    ];
    autostart = ws.autoStart;
  };
in
{
  config = mkMerge [
    (mkIf (cfg.enable && vmWorkspaces != { }) {
      # Convert VM workspace configs to microvm.nix format
      microvm.vms = mapAttrs mkVmConfig vmWorkspaces;
    })

    # microvm.nixosModules.host enables KSM, but /sys is read-only in containers
    (mkIf config.boot.isContainer {
      hardware.ksm.enable = false;
    })
  ];
}
