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
    ./drastikbot.nix
    ./radio.nix
  ];
}