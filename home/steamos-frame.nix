# Standalone home-manager config for the Steam Frame headset (SteamOS, aarch64).
# Nix is installed with the Determinate installer's steam-deck planner.
{ ... }:

{
  home.username = "steamos";
  home.homeDirectory = "/home/steamos";

  # Non-NixOS host: export Nix profile paths to the desktop session
  targets.genericLinux.enable = true;
}
