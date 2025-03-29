{ lib, config, pkgs, ... }:

let
  cfg = config.de;

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
  ] ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
    {
      name = "platformio-ide";
      publisher = "platformio";
      version = "3.1.1";
      sha256 = "g9yTG3DjVUS2w9eHGAai5LoIfEGus+FPhqDnCi4e90Q=";
    }
    {
      name = "wgsl-analyzer";
      publisher = "wgsl-analyzer";
      version = "0.8.1";
      sha256 = "ckclcxdUxhjWlPnDFVleLCWgWxUEENe0V328cjaZv+Y=";
    }
    {
      name = "volar";
      publisher = "Vue";
      version = "2.2.4";
      sha256 = "FHS/LNjSUVfCb4SVF9naR4W0JqycWzSWiK54jfbRagA=";
    }
  ];

  vscodium-with-extensions = pkgs.vscode-with-extensions.override {
    vscode = pkgs.vscodium;
    vscodeExtensions = extensions;
  };
in
{
  config = lib.mkIf cfg.enable {
    users.users.googlebot.packages = [
      vscodium-with-extensions
    ];
  };
}
