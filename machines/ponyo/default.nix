{ config, pkgs, lib, ... }:

# Being migrated to kif in phases. Phase 2 moved: thelounge, drastikbot,
# tmp.neet.dev, pgs, ntfy, gatus. Remaining here until later phases:
# nextcloud (3), matrix (4), gitea (5), mailserver (6).

{
  imports = [
    ./hardware-configuration.nix
  ];

  # system.autoUpgrade.enable = true;

  # p2p mesh network
  services.tailscale.exitNode = true;

  # Tailscale-only nginx virtual hosts bind to ponyo's stable tailnet address.
  services.nginx.tailscaleListenAddress = "100.76.85.13";

  # email server
  mailserver.enable = true;

  # nextcloud
  services.nextcloud.enable = true;

  # git
  services.gitea = {
    enable = true;
    hostname = "git.neet.dev";
    settings = {
      "repository.upload".FILE_MAX_SIZE = 1024;
      attachment.MAX_SIZE = 1024;
    };
  };

  # matrix home server
  services.matrix = {
    enable = true;
    host = "neet.space";
    publicFederation = false;
    enable_registration = false;
    element-web = {
      enable = true;
      host = "chat.neet.space";
    };
    jitsi-meet = {
      enable = false; # disabled until vulnerable libolm dependency is removed/fixed
      host = "meet.neet.space";
    };
    turn = {
      host = "turn.neet.space";
      useACMEHost = "neet.space";
      openFirewall = false;
      secret = "a8369a0e96922abf72494bb888c85831b";
    };
  };
  # pin postgresql for matrix (kif restores into an unpinned postgres in phase 4)
  services.postgresql.package = pkgs.postgresql_15;

  # proxied web services
  services.nginx.enable = true;

  # Keep public web listeners open overall, but pin selected vhosts to the tailnet address.
  services.nginx.virtualHosts."runyan.org" = {
    tailscaleOnly = true;
    useACMEHost = "runyan.org";
  };
  services.nginx.virtualHosts."collabora.runyan.org" = {
    tailscaleOnly = true;
    useACMEHost = "runyan.org";
  };
  services.nginx.virtualHosts."whiteboard.runyan.org" = {
    tailscaleOnly = true;
    useACMEHost = "runyan.org";
  };
  services.nginx.virtualHosts."git.neet.dev" = {
    tailscaleOnly = true;
    useACMEHost = "neet.dev";
    extraConfig = ''
      client_max_body_size 1g;
    '';
  };
  services.nginx.virtualHosts."neet.space" = {
    tailscaleOnly = true;
    useACMEHost = "neet.space";
  };
  services.nginx.virtualHosts."chat.neet.space" = {
    tailscaleOnly = true;
    useACMEHost = "neet.space";
  };
  services.nginx.virtualHosts."turn.neet.space" = {
    tailscaleOnly = true;
    useACMEHost = "neet.space";
  };

}
