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
    extensions = [
      "nix"
      "toml"
      "html"
      "make"
      "git-firefly"
      "vue"
      "scss"
    ];

    userSettings = {
      assistant = {
        enabled = true;
        version = "2";
        default_model = {
          provider = "openai";
          model = "gpt-4-turbo";
        };
      };

      features = {
        edit_prediction_provider = "zed";
      };

      node = {
        path = lib.getExe pkgs.nodejs;
        npm_path = lib.getExe' pkgs.nodejs "npm";
      };

      auto_update = false;

      terminal = {
        blinking = "off";
        copy_on_select = false;
      };

      lsp = {
        rust-analyzer = {
          # binary = {
          #   path = lib.getExe pkgs.rust-analyzer;
          # };
          binary = {
            path = "/run/current-system/sw/bin/nix";
            arguments = [ "develop" "--command" "rust-analyzer" ];
          };
          initialization_options = {
            cargo = {
              features = "all";
            };
          };
        };
      };

      # tell zed to use direnv and direnv can use a flake.nix enviroment.
      load_direnv = "shell_hook";

      base_keymap = "VSCode";
      theme = {
        mode = "system";
        light = "One Light";
        dark = "Andrometa";
      };
      ui_font_size = 12;
      buffer_font_size = 12;
    };
  };
}
