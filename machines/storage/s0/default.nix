{ config, pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./frigate.nix
    ./home-automation.nix
    ./media.nix
    ./minecraft-create.nix
  ];

  networking.hostName = "s0";

  ntfy-alerts.ignoredUnits = [ "logrotate" ];
  ntfy-alerts.ignoreTransientContainerUnitFailures = true;
  # FlareSolverr's Chromium startup self-test fails on boot and systemd
  # restarts it fine; only alert if it is still unhealthy after settling.
  ntfy-alerts.recoveryChecks.flaresolverr = {
    delaySec = 180;
    check = ''
      ${pkgs.curl}/bin/curl --silent --fail --max-time 10 \
        --output /dev/null http://127.0.0.1:48072/health
    '';
  };
  ntfy-alerts.dimmTempCheck.enable = true;

  # system.autoUpgrade.enable = true;


  services.iperf3.enable = true;
  services.iperf3.openFirewall = true;

  # p2p mesh network
  services.tailscale.exitNode = true;

  # for education purposes only
  services.pykms.enable = true;
  services.pykms.openFirewallPort = true;

  # samba
  services.samba.enable = true;

  # VAAPI decode/encode comes from mesa's radeonsi driver (Ryzen 7900X iGPU),
  # which hardware.graphics.enable already provides
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      rocmPackages.clr.icd # OpenCL filter support (hardware tonemapping and subtitle burn-in)
    ];
  };

  # nginx
  services.nginx = {
    enable = true;
    openFirewall = false; # All nginx services are internal
    virtualHosts =
      let
        mkHost = external: config:
          {
            ${external} = {
              useACMEHost = "s0.neet.dev"; # Use wildcard cert
              forceSSL = true;
              locations."/" = config;
            };
          };
        mkVirtualHost = external: internal:
          mkHost external {
            proxyPass = internal;
            proxyWebsockets = true;
          };
        mkStaticHost = external: static:
          mkHost external {
            root = static;
            tryFiles = "$uri /index.html ";
          };
      in
      lib.mkMerge [
        (mkVirtualHost "bazarr.s0.neet.dev" "http://servarr.containers:6767")
        (mkVirtualHost "radarr.s0.neet.dev" "http://servarr.containers:7878")
        (mkVirtualHost "lidarr.s0.neet.dev" "http://servarr.containers:8686")
        (mkVirtualHost "sonarr.s0.neet.dev" "http://servarr.containers:8989")
        (mkVirtualHost "prowlarr.s0.neet.dev" "http://servarr.containers:9696")
        (mkVirtualHost "transmission.s0.neet.dev" "http://transmission.containers:8080")
        (mkVirtualHost "unifi.s0.neet.dev" "https://localhost:8443")
        (mkVirtualHost "jellyfin.s0.neet.dev" "http://localhost:8096")
        (mkStaticHost "s0.neet.dev" config.services.dashy.finalDrv)
        {
          # Landing page LAN redirect
          "s0" = {
            default = true;
            redirectCode = 302;
            globalRedirect = "s0.neet.dev";
          };
        }
        (mkVirtualHost "ha.s0.neet.dev" "http://localhost:${toString config.services.home-assistant.config.http.server_port}")
        (mkVirtualHost "esphome.s0.neet.dev" "http://localhost:6052")
        (mkVirtualHost "zigbee.s0.neet.dev" "http://localhost:55834")
        {
          "frigate.s0.neet.dev" = {
            # Just configure SSL, frigate module configures the rest of nginx
            useACMEHost = "s0.neet.dev";
            forceSSL = true;
          };
        }
        (mkVirtualHost "vacuum.s0.neet.dev" "http://192.168.1.125") # valetudo
        (mkVirtualHost "sandman.s0.neet.dev" "http://192.168.0.109:3000") # es
        (mkVirtualHost "todo.s0.neet.dev" "http://localhost:${toString config.services.vikunja.port}")
        (mkVirtualHost "budget.s0.neet.dev" "http://localhost:${toString config.services.actual.settings.port}") # actual budget
        (mkVirtualHost "linkwarden.s0.neet.dev" "http://localhost:${toString config.services.linkwarden.port}")
        (mkVirtualHost "memos.s0.neet.dev" "http://localhost:${toString config.services.memos.settings.MEMOS_PORT}")
        (mkVirtualHost "outline.s0.neet.dev" "http://localhost:${toString config.services.outline.port}")
      ];

    tailscaleAuth = {
      enable = false; # Disabled for now because it doesn't work with tailscale's ACL tagged groups
      virtualHosts = [
        "bazarr.s0.neet.dev"
        "radarr.s0.neet.dev"
        "lidarr.s0.neet.dev"
        "sonarr.s0.neet.dev"
        "prowlarr.s0.neet.dev"
        "transmission.s0.neet.dev"
        "unifi.s0.neet.dev"
        "jellyfin.s0.neet.dev"
        "s0.neet.dev"
        # "ha.s0.neet.dev" # messes up home assistant
        "esphome.s0.neet.dev"
        "zigbee.s0.neet.dev"
        "vacuum.s0.neet.dev"
        "todo.s0.neet.dev"
        "budget.s0.neet.dev"
        "linkwarden.s0.neet.dev"
        # "memos.s0.neet.dev" # messes up memos /auth route
        # "outline.s0.neet.dev" # messes up outline /auth route
      ];
      expectedTailnet = "koi-bebop.ts.net";
    };
  };

  virtualisation.oci-containers.backend = "podman";
  virtualisation.podman.dockerSocket.enable = true; # TODO needed?
  services.dashy = {
    enable = true;
    settings = import ./dashy.nix;
  };

  services.unifi = {
    enable = true;
    openMinimalFirewall = true;
  };

  services.vikunja = {
    enable = true;
    port = 61473;
    frontendScheme = "https";
    frontendHostname = "todo.s0.neet.dev";
    settings = {
      service.enableregistration = false;
    };
  };
  backup.group."vikunja".paths = [
    "/var/lib/vikunja"
  ];

  services.actual.enable = true;

  services.linkwarden = {
    enable = true;
    enableRegistration = true;
    port = 41709;
    environment.NEXTAUTH_URL = "https://linkwarden.s0.neet.dev/api/v1/auth";
    environmentFile = "/run/agenix/linkwarden-environment";
  };
  age.secrets.linkwarden-environment.file = ../../../secrets/linkwarden-environment.age;
  services.meilisearch = {
    enable = true;
    package = pkgs.meilisearch;
  };

  services.flaresolverr = {
    enable = true;
    port = 48072;
  };

  services.memos = {
    enable = true;
    settings = {
      MEMOS_MODE = "prod";
      MEMOS_ADDR = "127.0.0.1";
      MEMOS_PORT = "57643";
      MEMOS_DATA = config.services.memos.dataDir;
      MEMOS_DRIVER = "sqlite";
      MEMOS_INSTANCE_URL = "https://memos.s0.neet.dev";
    };
  };
  # ReadWritePaths doesn't work with ProtectSystem=strict on ZFS submounts (/var/lib is a separate dataset)
  systemd.services.memos.serviceConfig.ProtectSystem = lib.mkForce "full";

  services.outline = {
    enable = true;
    forceHttps = false; # https through nginx
    port = 43933;
    publicUrl = "https://outline.s0.neet.dev";
    storage.storageType = "local";
    smtp = {
      secure = true;
      fromEmail = "robot@runyan.org";
      username = "robot@runyan.org";
      replyEmail = "robot@runyan.org";
      host = "mail.neet.dev";
      port = 465;
      passwordFile = "/run/agenix/robots-email-pw";
    };
  };
  age.secrets.robots-email-pw = {
    file = ../../../secrets/robots-email-pw.age;
    owner = config.services.outline.user;
  };

  boot.binfmt.emulatedSystems = [ "aarch64-linux" "armv7l-linux" ];
}
