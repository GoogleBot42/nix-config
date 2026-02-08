{ config, lib, pkgs, ... }:

# Example VM workspace configuration
#
# Add to sandboxed-workspace.workspaces in machines/fry/default.nix:
#   sandboxed-workspace.workspaces.example = {
#     type = "vm";
#     config = ./workspaces/example.nix;
#     ip = "192.168.83.10";
#   };
#
# The workspace name ("example") becomes the hostname automatically.
# The IP is configured in default.nix, not here.

{
  # Install packages as needed
  environment.systemPackages = with pkgs; [
    # Add packages here
  ];

  # Additional shares beyond the standard ones (workspace, ssh-host-keys, claude-config):
  # microvm.shares = [ ... ];
}
