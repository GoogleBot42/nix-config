{ lib, pkgs, ... }:

# Home Manager configuration for sandboxed workspace user environment
# This sets up the shell and tools inside VMs and containers

{
  home.username = "googlebot";
  home.homeDirectory = "/home/googlebot";
  home.stateVersion = "24.11";

  programs.home-manager.enable = true;

  # Shell configuration
  programs.fish.enable = true;
  programs.starship.enable = true;
  programs.starship.enableFishIntegration = true;
  programs.starship.settings.container.disabled = true;

  # Basic command-line tools
  programs.btop.enable = true;
  programs.ripgrep.enable = true;
  programs.eza.enable = true;

  # Git configuration
  programs.git = {
    enable = true;
    settings = {
      user.name = lib.mkDefault "googlebot";
      user.email = lib.mkDefault "zuckerberg@neet.dev";
    };
  };

  # Shell aliases
  home.shellAliases = {
    ls = "eza";
    la = "eza -la";
    ll = "eza -l";
  };

  # Environment variables for Claude Code
  home.sessionVariables = {
    # Isolate Claude config to a specific directory on the host
    CLAUDE_CONFIG_DIR = "/home/googlebot/claude-config";
  };

  # Additional packages for development
  home.packages = with pkgs; [
    # Add packages as needed per workspace
  ];
}
