{ config, pkgs, lib, ... }:


let
  cfg = config.services.nextcloud;

  nextcloudHostname = "runyan.org";
  collaboraOnlineHostname = "collabora.runyan.org";
  whiteboardHostname = "whiteboard.runyan.org";
  whiteboardPort = 3002; # Seems impossible to change

  # Hardcoded public ip of ponyo... I wish I didn't need this...
  public_ip_address = "147.135.114.130";

  nixManagedApps = builtins.attrNames cfg.extraApps;
  nixManagedAppsPattern = lib.concatStringsSep "|" nixManagedApps;
in
{
  config = lib.mkIf cfg.enable {
    services.nextcloud = {
      https = true;
      package = pkgs.nextcloud32;
      hostName = nextcloudHostname;
      config.dbtype = "sqlite";
      config.adminuser = "jeremy";
      config.adminpassFile = "/run/agenix/nextcloud-pw";

      # Apps
      autoUpdateApps.enable = true;
      extraAppsEnable = true;
      extraApps = with config.services.nextcloud.package.packages.apps; {
        # Want
        inherit end_to_end_encryption mail spreed;

        # For file and document editing (collabora online and excalidraw)
        inherit richdocuments whiteboard;

        # Might use
        inherit calendar qownnotesapi;

        # Try out
        # inherit bookmarks cookbook deck memories maps music news notes phonetrack polls forms;
      };

      # Allows installing Apps from the UI (might remove later)
      appstoreEnable = true;
    };

    # Nix-managed apps (extraApps) live in the read-only nix store. If Nextcloud
    # downloads a newer version into store-apps/, both get loaded by PHP causing
    # a fatal class redeclaration error and leaving NC stuck in maintenance mode.
    # Fix: (1) clean store-apps/ of nix-managed duplicates before setup/upgrade,
    # (2) skip nix-managed apps during auto-updates.
    systemd.services.nextcloud-setup.preStart = lib.mkAfter ''
      for app in ${lib.escapeShellArgs nixManagedApps}; do
        if [ -d "${cfg.home}/store-apps/$app" ]; then
          rm -rf "${cfg.home}/store-apps/$app"
        fi
      done
    '';
    systemd.services.nextcloud-update-plugins = {
      path = [ config.services.nextcloud.occ ];
      serviceConfig.ExecStart = lib.mkForce (toString (pkgs.writeShellScript "nextcloud-update-non-nix-apps" ''
        apps=$(nextcloud-occ app:update --showonly | awk '{print $1}' | grep -vE '^(${nixManagedAppsPattern})$' || true)
        for app in $apps; do
          nextcloud-occ app:update "$app"
        done
      ''));
    };
    age.secrets.nextcloud-pw = {
      file = ../../secrets/nextcloud-pw.age;
      owner = "nextcloud";
    };

    # backups
    backup.group."nextcloud".paths = [
      config.services.nextcloud.home
    ];

    services.nginx.virtualHosts.${config.services.nextcloud.hostName} = {
      enableACME = true;
      forceSSL = true;
    };

    # collabora-online
    # https://diogotc.com/blog/collabora-nextcloud-nixos/
    services.collabora-online = {
      enable = true;
      port = 15972;
      settings = {
        # Rely on reverse proxy for SSL
        ssl = {
          enable = false;
          termination = true;
        };

        # Listen on loopback interface only
        net = {
          listen = "loopback";
          post_allow.host = [ "localhost" ];
        };

        # Restrict loading documents from WOPI Host
        storage.wopi = {
          "@allow" = true;
          host = [ config.services.nextcloud.hostName ];
        };

        server_name = collaboraOnlineHostname;
      };
    };
    services.nginx.virtualHosts.${config.services.collabora-online.settings.server_name} = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://localhost:${toString config.services.collabora-online.port}";
        proxyWebsockets = true;
      };
    };
    systemd.services.nextcloud-config-collabora =
      let
        wopi_url = "http://localhost:${toString config.services.collabora-online.port}";
        public_wopi_url = "https://${collaboraOnlineHostname}";
        wopi_allowlist = lib.concatStringsSep "," [
          "127.0.0.1"
          "::1"
          public_ip_address
        ];
      in
      {
        wantedBy = [ "multi-user.target" ];
        after = [ "nextcloud-setup.service" "coolwsd.service" ];
        requires = [ "coolwsd.service" ];
        path = [
          config.services.nextcloud.occ
        ];
        script = ''
          nextcloud-occ config:app:set richdocuments wopi_url --value ${lib.escapeShellArg wopi_url}
          nextcloud-occ config:app:set richdocuments public_wopi_url --value ${lib.escapeShellArg public_wopi_url}
          nextcloud-occ config:app:set richdocuments wopi_allowlist --value ${lib.escapeShellArg wopi_allowlist}
          nextcloud-occ richdocuments:setup
        '';
        serviceConfig = {
          Type = "oneshot";
        };
      };

    # Whiteboard
    services.nextcloud-whiteboard-server = {
      enable = true;
      settings.NEXTCLOUD_URL = "https://${nextcloudHostname}";
      secrets = [ "/run/agenix/whiteboard-server-jwt-secret" ];
    };
    systemd.services.nextcloud-config-whiteboard = {
      wantedBy = [ "multi-user.target" ];
      after = [ "nextcloud-setup.service" ];
      requires = [ "coolwsd.service" ];
      path = [
        config.services.nextcloud.occ
      ];
      script = ''
        nextcloud-occ config:app:set whiteboard collabBackendUrl --value="https://${whiteboardHostname}"
        nextcloud-occ config:app:set whiteboard jwt_secret_key --value="$JWT_SECRET_KEY"
      '';
      serviceConfig = {
        Type = "oneshot";
        EnvironmentFile = [ "/run/agenix/whiteboard-server-jwt-secret" ];
      };
    };
    age.secrets.whiteboard-server-jwt-secret.file = ../../secrets/whiteboard-server-jwt-secret.age;
    services.nginx.virtualHosts.${whiteboardHostname} = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://localhost:${toString whiteboardPort}";
        proxyWebsockets = true;
      };
    };
  };
}
