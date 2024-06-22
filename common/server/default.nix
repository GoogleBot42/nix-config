{ config, pkgs, ... }:

{
  imports = [
    ./nginx.nix
    ./thelounge.nix
    ./mumble.nix
    ./icecast.nix
    ./nginx-stream.nix
    ./matrix.nix
    ./zerobin.nix
    ./gitea.nix
    ./privatebin/privatebin.nix
    ./radio.nix
    ./samba.nix
    ./owncast.nix
    ./mailserver.nix
    ./nextcloud.nix
    ./iodine.nix
    ./searx.nix
    ./gitea-actions-runner.nix
    ./dashy.nix
    ./librechat.nix
    ./actualbudget.nix
    ./unifi.nix
  ];
}
