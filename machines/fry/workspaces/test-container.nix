{ config, lib, pkgs, ... }:

# Test container workspace configuration
#
# Add to sandboxed-workspace.workspaces in machines/fry/default.nix:
#   sandboxed-workspace.workspaces.test-container = {
#     type = "container" OR "incus";
#     config = ./workspaces/test-container.nix;
#     ip = "192.168.83.50";
#   };
#
# The workspace name ("test-container") becomes the hostname automatically.
# The IP is configured in default.nix, not here.

{
  # Install packages as needed
  environment.systemPackages = with pkgs; [
    # Add packages here
  ];
}
