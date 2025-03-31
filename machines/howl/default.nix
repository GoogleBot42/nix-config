{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # don't use remote builders
  nix.distributedBuilds = lib.mkForce false;

  nix.gc.automatic = lib.mkForce false;

  services.resolved.enable = true;

  # services.firezone.headless-client = {
  #   enable = true;
  #   name = config.networking.hostName;
  #   apiUrl = "wss://api.firezone.dev/";
  #   tokenFile = "/run/agenix/firezone-token";
  # };
  # age.secrets.firezone-token.file = ../../secrets/firezone-token.age;

  # services.firezone.gui-client = {
  #   enable = true;
  #   name = config.networking.hostName;
  #   allowedUsers = [ "googlebot" ];
  # };
}
