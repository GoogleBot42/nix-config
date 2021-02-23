{ config, pkgs, ... }:

let
  extensions = with pkgs.vscode-extensions; [
    bbenoist.Nix # nix syntax support
#    arrterian.nix-env-selector  # nix dev envs
  ];

  vscodium-with-extensions = pkgs.vscode-with-extensions.override {
    vscode = pkgs.vscodium;
    vscodeExtensions = extensions;
  };
in
{
  users.users.googlebot.packages = [
    vscodium-with-extensions
  ];
}
