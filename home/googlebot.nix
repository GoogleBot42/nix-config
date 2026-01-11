{ config, lib, pkgs, osConfig, ... }:

let
  # Check if the current machine has the role "personal"
  thisMachineIsPersonal = osConfig.thisMachine.hasRole."personal";
in
{
  home.username = "googlebot";
  home.homeDirectory = "/home/googlebot";

  home.stateVersion = "24.11";
  programs.home-manager.enable = true;

  services.ssh-agent.enable = true;
  # Configure ssh askpass correctly
  systemd.user.services.ssh-agent.Service.Environment = [
    "SSH_ASKPASS=${pkgs.kdePackages.ksshaskpass}/bin/ksshaskpass"
  ];

  # System Monitoring
  programs.btop.enable = true;
  programs.bottom.enable = true;

  # Modern "ls" replacement
  programs.pls.enable = true;
  programs.pls.enableFishIntegration = false;
  programs.eza.enable = true;

  # Graphical terminal
  programs.ghostty.enable = thisMachineIsPersonal;
  programs.ghostty.settings = {
    theme = "Snazzy";
    font-size = 10;
  };

  # Advanced terminal file explorer
  programs.broot.enable = true;

  # Shell promt theming
  programs.fish.enable = true;
  programs.starship.enable = true;
  programs.starship.enableFishIntegration = true;
  programs.starship.enableInteractive = true;
  # programs.oh-my-posh.enable = true;
  # programs.oh-my-posh.enableFishIntegration = true;

  # Advanced search
  programs.ripgrep.enable = true;

  # tldr: Simplified, example based and community-driven man pages.
  programs.tealdeer.enable = true;

  home.shellAliases = {
    sudo = "doas";
    ls2 = "eza";
    explorer = "broot";
  };

  programs.zed-editor = {
    enable = thisMachineIsPersonal;
  };
}
