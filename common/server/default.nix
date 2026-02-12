{ ... }:

{
  imports = [
    ./nginx.nix
    ./thelounge.nix
    ./mumble.nix
    ./matrix.nix
    ./gitea.nix
    ./samba.nix
    ./owncast.nix
    ./mailserver.nix
    ./nextcloud.nix
    ./gitea-actions-runner.nix
    ./librechat.nix
    ./actualbudget.nix
    ./unifi.nix
  ];
}
