{ hostname, machineRoles }:
{ config, lib, pkgs, ... }:

let
  # Check if the current machine has the role "personal"
  thisMachineIsPersonal = builtins.elem hostname machineRoles.personal;
in
{
  home.username = "googlebot";
  home.homeDirectory = "/home/googlebot";

  home.stateVersion = "24.11";
  programs.home-manager.enable = true;

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
