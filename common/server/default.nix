{ ... }:

{
  imports = [
    ./nginx.nix
    ./thelounge.nix
    ./matrix.nix
    ./gitea.nix
    ./samba.nix
    ./mailserver.nix
    ./nextcloud.nix
    ./gitea-actions-runner.nix
    ./atticd.nix
    ./actualbudget.nix
    ./unifi.nix
    ./ntfy.nix
    ./gatus.nix
    ./pgs.nix
  ];
}
