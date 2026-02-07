{ config, lib, pkgs, osConfig, ... }:

# https://home-manager-options.extranix.com/
# https://nix-community.github.io/home-manager/options.xhtml

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

  programs.vscode = {
    enable = thisMachineIsPersonal;
    package = pkgs.vscodium;
    profiles.default = {
      userSettings = {
        editor.formatOnSave = true;
        nix = {
          enableLanguageServer = true;
          serverPath = "${pkgs.nil}/bin/nil";
          serverSettings.nil = {
            formatting.command = [ "${pkgs.nixpkgs-fmt}/bin/nixpkgs-fmt" ];
            nix.flake.autoArchive = true;
          };
        };
        dotnetAcquisitionExtension.sharedExistingDotnetPath = "${pkgs.dotnet-sdk_9}/bin";
        godotTools = {
          lsp.serverPort = 6005; # port needs to match Godot configuration
          editorPath.godot4 = "godot-mono";
        };
      };
      extensions = with pkgs.vscode-extensions; [
        bbenoist.nix # nix syntax support
        arrterian.nix-env-selector # nix dev envs
        dart-code.dart-code
        dart-code.flutter
        golang.go
        jnoortheen.nix-ide
        ms-vscode.cpptools
        rust-lang.rust-analyzer
        vadimcn.vscode-lldb
        tauri-apps.tauri-vscode
        platformio.platformio-vscode-ide
        vue.volar
        wgsl-analyzer.wgsl-analyzer

        # Godot
        geequlim.godot-tools # For Godot GDScript support
        ms-dotnettools.csharp
        ms-dotnettools.vscode-dotnet-runtime
      ];
    };
  };

  home.packages = lib.mkIf thisMachineIsPersonal [
    pkgs.dotnetCorePackages.dotnet_9.sdk # For Godot-Mono VSCode-Extension CSharp
  ];
}
