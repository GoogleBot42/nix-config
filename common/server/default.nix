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
    ./cloudflared.nix
  ];
}