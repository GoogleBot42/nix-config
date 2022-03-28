{ config, pkgs, ... }:

{
  imports = [
    ./archivebox
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
  ];
}