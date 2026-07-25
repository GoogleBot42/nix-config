{ config, pkgs, lib, ... }:

# Being migrated to kif in phases. Phases 2-4 moved: thelounge, drastikbot,
# tmp.neet.dev, pgs, ntfy, gatus, nextcloud, matrix. Remaining here:
# gitea (5), mailserver (6).

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

  # git
  services.gitea = {
    enable = true;
    hostname = "git.neet.dev";
    settings = {
      "repository.upload".FILE_MAX_SIZE = 1024;
      attachment.MAX_SIZE = 1024;
    };
  };

  # proxied web services
  services.nginx.enable = true;

  # Keep public web listeners open overall, but pin selected vhosts to the tailnet address.
  services.nginx.virtualHosts."git.neet.dev" = {
    tailscaleOnly = true;
    useACMEHost = "neet.dev";
    extraConfig = ''
      client_max_body_size 1g;
    '';
  };

}
