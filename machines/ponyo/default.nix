{ config, pkgs, lib, ... }:

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
  };

  # IRC
  services.thelounge = {
    enable = true;
    port = 9000;
    fileUploadBaseUrl = "https://files.neet.cloud/irc/";
    host = "irc.neet.dev";
    fileHost = {
      host = "files.neet.cloud";
      path = "/irc";
    };
  };

  # IRC bot
  services.drastikbot = {
    enable = true;
    wolframAppIdFile = "/run/agenix/wolframalpha";
  };
  age.secrets.wolframalpha = {
    file = ../../secrets/wolframalpha.age;
    owner = config.services.drastikbot.user;
  };
  backup.group."dailybot".paths = [
    config.services.drastikbot.dataDir
  ];

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
  # pin postgresql for matrix (will need to migrate eventually)
  services.postgresql.package = pkgs.postgresql_15;

  # proxied web services
  services.nginx.enable = true;

  # TODO replace with a proper file hosting service
  services.nginx.virtualHosts."tmp.neet.dev" = {
    useACMEHost = "neet.dev";
    forceSSL = true;
    root = "/var/www/tmp";
  };

  # pgs static site hosting
  services.pgs = {
    enable = true;
    domain = "sites.neet.dev";
    sshHost = config.services.nginx.tailscaleListenAddress;
    initialUsers.jeremy = config.machines.ssh.userKeys;
    initialUsers.hermes = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILCUueCIRiGWWWsDrwi828G32afRHHpBOisbbYJzRFjn"
    ];
    initialUsers.claude = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIOLN3ec0oA0Md/9RZEpcoWv3hgWo1aRBco9PZSkWWQl"
    ];
    initialUsers.bevy_voxel = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMR32OsK8nVYi7GruL6J4JszDzb+nrBwEBYBhrRIdyx7"
    ];
    nginx.enable = true;
  };

  # push notifications
  services.ntfy-sh.enable = true;
  services.ntfy-sh.hostname = "ntfy.neet.dev";

  # uptime monitoring
  services.gatus.enable = true;
  services.gatus.hostname = "status.neet.dev";

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
  };
  services.nginx.virtualHosts."irc.neet.dev" = {
    tailscaleOnly = true;
    useACMEHost = "neet.dev";
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
  services.nginx.virtualHosts."status.neet.dev" = {
    tailscaleOnly = true;
    useACMEHost = "neet.dev";
  };
  services.nginx.virtualHosts."ntfy.neet.dev" = {
    useACMEHost = "neet.dev";
  };

}
