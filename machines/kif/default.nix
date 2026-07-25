{ config, pkgs, lib, ... }:

# Services migrate here from ponyo in phases (phase 2: low-risk web services).
# Remaining on ponyo until later phases: nextcloud, matrix, gitea, mailserver.
#
# system.stateVersion is deliberately NOT set here: common/default.nix pins it
# fleet-wide to "23.11" (a plain, non-mkDefault assignment that every machine —
# ponyo, s0, etc. — inherits). Overriding it for kif alone would both conflict
# with that assignment and desync kif from the fleet it is inheriting services
# from. Keeping the fleet value is the correct choice for these migrations.

{
  imports = [
    ./hardware-configuration.nix
    ./disko.nix
  ];

  # Claude agent key, authorized for the ponyo->kif migration (state sync,
  # remote LUKS unlock, host key harvest). Remove at Phase 7 decommission.
  # Also flows into remoteLuksUnlock.sshAuthorizedKeys via its default.
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFlGtWc9X6vs6YLyrC5BC8ZWm+KVOG40uRY4Tj7fjSKL claude-agent-devbox"
  ];

  # proxied web services
  services.nginx.enable = true;

  # email server
  mailserver.enable = true;

  # nextcloud
  services.nextcloud.enable = true;

  # Explicit version required: the module default follows stateVersion (23.11
  # fleet-wide -> postgres 15).
  services.postgresql.package = pkgs.postgresql_17;

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

  # Tailscale-only nginx virtual hosts bind to kif's stable tailnet address.
  services.nginx.tailscaleListenAddress = "100.89.83.99";

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
    maxSize = 1024 * 1024 * 1024;
    maxAssetSize = 100 * 1024 * 1024;
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

  # Keep public web listeners open overall, but pin selected vhosts to the
  # tailnet address.
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
  services.nginx.virtualHosts."git.neet.dev" = {
    tailscaleOnly = true;
    useACMEHost = "neet.dev";
    extraConfig = ''
      client_max_body_size 1g;
    '';
  };
  services.nginx.virtualHosts."irc.neet.dev" = {
    tailscaleOnly = true;
    useACMEHost = "neet.dev";
  };
  services.nginx.virtualHosts."status.neet.dev" = {
    tailscaleOnly = true;
    useACMEHost = "neet.dev";
  };
  services.nginx.virtualHosts."ntfy.neet.dev" = {
    useACMEHost = "neet.dev";
  };
  # Public upload-link host for thelounge; wildcard DNS-01 cert avoids the
  # http-01 chicken-and-egg while DNS still points at ponyo during cutover.
  services.nginx.virtualHosts."files.neet.cloud" = {
    useACMEHost = "neet.cloud";
  };
}
