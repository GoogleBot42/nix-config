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
    platformio.platformio-vscode-ide
    vue.volar
  ] ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
    {
      name = "wgsl-analyzer";
      publisher = "wgsl-analyzer";
      version = "0.12.105";
      sha256 = "sha256-NheEVNIa8CIlyMebAhxRKS44b1bZiWVt8PgC6r3ExMA=";
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
