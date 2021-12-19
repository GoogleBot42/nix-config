{ lib, config, pkgs, ... }:

let
  cfg = config.de;

  extensions = with pkgs.vscode-extensions; [
#    bbenoist.Nix # nix syntax support
#    arrterian.nix-env-selector  # nix dev envs
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
