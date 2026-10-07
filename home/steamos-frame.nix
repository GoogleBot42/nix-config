# Standalone home-manager config for the Steam Frame headset (SteamOS, aarch64).
# Nix is installed with NixOS/nix-installer's steam-deck planner, which keeps
# the store at /home/nix. After each switch, run `steamos-etc` to install the
# root-owned /etc files below (it prompts for sudo).
{ ... }:

{
  home.username = "steamos";
  home.homeDirectory = "/home/steamos";

  # Non-NixOS host: export Nix profile paths to the desktop session
  targets.genericLinux.enable = true;

  programs.steamos-etc = {
    enable = true;
    # Mesa (Turnip for the Adreno GPU) at /run/opengl-driver for Nix apps
    gpuDrivers = true;
    # Hold the user session until /nix is mounted so store links resolve
    waitForNix = true;
  };
}
