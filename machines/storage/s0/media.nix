{ config, lib, pkgs, ... }:

# Media stack: Transmission and the *arr apps run in containers routed through
# the PIA VPN; Jellyfin runs on the host because the containers cannot reach
# the GPU encoder.
#
# Permission model: every service runs as its own user with `public_data` as
# primary group. The shared library stays group-owned by public_data with
# setgid directories and group-writable files, and every writer (the services
# via umask 002, Samba via its share masks) creates group-writable files. That
# lets the *arr apps hardlink or rename downloads owned by Transmission
# (protected_hardlinks requires rw on the source), lets Jellyfin and Samba
# clients read everything, and keeps each service's own state directory
# private to it.

let
  cfg = config.pia-vpn;

  mediaDir = "/data/samba/Public/Media";
  downloadDir = "${mediaDir}/Transmission";

  # bazarr has no static id in nixpkgs, and the containers are ephemeral so a
  # dynamically allocated uid would not survive a restart. 399 sits above the
  # static ids nixpkgs assigns and below its dynamic range (400-999).
  bazarrUid = 399;

  serviceUsers = {
    transmission = config.ids.uids.transmission;
    sonarr = config.ids.uids.sonarr;
    radarr = config.ids.uids.radarr;
    lidarr = config.ids.uids.lidarr;
    bazarr = bazarrUid;
  };

  mkUsers = names: lib.genAttrs names (name: {
    isSystemUser = true;
    uid = serviceUsers.${name};
    group = "public_data";
  });

  # Container-side accounts pinned to the same ids as the host so ownership of
  # the bind-mounted state and library resolves identically on both sides.
  # This relies on the containers running without a user namespace
  # (`privateUsers = "no"`, the nixos-containers default); enabling
  # `--private-users` would shift every id on the bind mounts.
  mkServiceUsers = names: {
    users.groups.public_data.gid = config.users.groups.public_data.gid;
    users.users = mkUsers names;
  };

  # The nixpkgs modules default to UMask 0022; files must be group-writable
  # for the hand-off between services. Kept as a module: the pia-vpn container
  # option merges plain attrsets and strips mkForce on the way in.
  groupWritable = names: {
    systemd.services = lib.genAttrs names (_: {
      serviceConfig.UMask = lib.mkForce "0002";
    });
  };
in
{
  pia-vpn = {
    enable = true;
    serverLocation = "swiss";

    containers.transmission = {
      ip = "10.100.0.10";
      # Transmission only writes to its own download folder; the *arr apps pull
      # from it, so it needs nothing else from the library. Mounting all of
      # /var/lib would hand the most internet-exposed container write access
      # to every other service's state.
      mounts."/var/lib/transmission".hostPath = "/var/lib/transmission";
      mounts.${downloadDir}.hostPath = downloadDir;
      receiveForwardedPort = { protocol = "both"; };
      onPortForwarded = ''
        # Notify Transmission of the PIA-assigned peer port via RPC
        for i in $(seq 1 30); do
          curlout=$(curl -s "http://transmission.containers:8080/transmission/rpc" 2>/dev/null) && break
          sleep 2
        done
        regex='X-Transmission-Session-Id: (\w*)'
        if [[ $curlout =~ $regex ]]; then
          sessionId=''${BASH_REMATCH[1]}
          curl -s "http://transmission.containers:8080/transmission/rpc" \
            -d "{\"method\":\"session-set\",\"arguments\":{\"peer-port\":$PORT}}" \
            -H "X-Transmission-Session-Id: $sessionId"
        fi
      '';
      config = {
        imports = [ (mkServiceUsers [ "transmission" ]) ];

        services.transmission = {
          enable = true;
          package = pkgs.transmission_4;
          performanceNetParameters = true;
          group = "public_data";
          settings = {
            "download-dir" = downloadDir;
            "incomplete-dir" = "/var/lib/transmission/.incomplete";
            "incomplete-dir-enabled" = true;
            umask = "002";

            "rpc-enabled" = true;
            "rpc-port" = 8080;
            "rpc-bind-address" = "0.0.0.0";
            # Only nginx on the host and the port-forward hook in the VPN
            # container talk to the RPC socket.
            "rpc-whitelist" = "127.0.0.1,${cfg.hostAddress},${cfg.vpnAddress}";
            "rpc-host-whitelist-enabled" = false;

            "port-forwarding-enabled" = true;
            "peer-port" = 51413;
            "peer-port-random-on-start" = false;

            "encryption" = 1;
            "lpd-enabled" = true;
            "dht-enabled" = true;
            "pex-enabled" = true;

            "blocklist-enabled" = true;
            "blocklist-updates-enabled" = true;
            "blocklist-url" = "https://github.com/Naunter/BT_BlockLists/raw/master/bt_blocklists.gz";

            "ratio-limit" = 3;
            "ratio-limit-enabled" = true;

            "download-queue-enabled" = true;
            "download-queue-size" = 20;
          };
        };
        # https://github.com/NixOS/nixpkgs/issues/258793
        systemd.services.transmission.serviceConfig = {
          RootDirectoryStartOnly = lib.mkForce (lib.mkForce false);
          RootDirectory = lib.mkForce (lib.mkForce "");
          TimeoutStopSec = "30s";
        };
        systemd.services.transmission-health-check = {
          description = "Restart Transmission when its RPC endpoint hangs";
          after = [ "transmission.service" ];
          serviceConfig.Type = "oneshot";
          script = ''
            if ! ${pkgs.curl}/bin/curl --silent --show-error --max-time 10 \
              --output /dev/null http://127.0.0.1:8080/transmission/rpc; then
              systemctl restart transmission.service
            fi
          '';
        };
        systemd.timers.transmission-health-check = {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "5m";
            OnUnitActiveSec = "2m";
            Unit = "transmission-health-check.service";
          };
        };
      };
    };

    containers.servarr = {
      ip = "10.100.0.11";
      # Persist only the state of the services in this container (see note on
      # the transmission container). Prowlarr uses DynamicUser, so its state
      # lives under /var/lib/private.
      mounts."/var/lib/sonarr".hostPath = "/var/lib/sonarr";
      mounts."/var/lib/radarr".hostPath = "/var/lib/radarr";
      mounts."/var/lib/lidarr".hostPath = "/var/lib/lidarr";
      mounts."/var/lib/bazarr".hostPath = "/var/lib/bazarr";
      mounts."/var/lib/private/prowlarr".hostPath = "/var/lib/private/prowlarr";
      # The library must be one mount: hardlinking a download into TV/Movies/
      # Music fails with EXDEV across separate bind mounts, even of one
      # filesystem, and the *arr apps would silently fall back to copying.
      mounts.${mediaDir}.hostPath = mediaDir;
      config = {
        imports = [
          (mkServiceUsers [ "sonarr" "radarr" "lidarr" "bazarr" ])
          (groupWritable [ "sonarr" "radarr" "lidarr" "bazarr" ])
        ];

        # nspawn creates the /var/lib/private mount-point parent as 0755, but
        # systemd refuses DynamicUser state directories unless it is 0700.
        systemd.tmpfiles.rules = [ "d /var/lib/private 0700 root root -" ];

        services.prowlarr.enable = true;
        services.sonarr = {
          enable = true;
          group = "public_data";
        };
        services.radarr = {
          enable = true;
          group = "public_data";
        };
        services.lidarr = {
          enable = true;
          group = "public_data";
        };
        services.bazarr = {
          enable = true;
          group = "public_data";
        };
      };
    };
  };

  # jellyfin cannot run in the vpn container and use hardware encoding
  # I could not figure out how to allow the container to access the encoder
  services.jellyfin.enable = true;
  systemd.services.jellyfin-health-check = {
    description = "Restart Jellyfin when its health endpoint hangs";
    after = [ "jellyfin.service" ];
    serviceConfig.Type = "oneshot";
    script = ''
      if systemctl is-active --quiet jellyfin.service && \
        ! ${pkgs.curl}/bin/curl --silent --show-error --fail --max-time 10 \
          --output /dev/null http://127.0.0.1:8096/health; then
        systemctl restart jellyfin.service
      fi
    '';
  };
  systemd.timers.jellyfin-health-check = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "10m";
      OnUnitActiveSec = "2m";
      Unit = "jellyfin-health-check.service";
    };
  };

  # Host-side accounts for the container services (the public_data group comes
  # from the Samba module); Jellyfin reads the library through that group.
  users.users = mkUsers (lib.attrNames serviceUsers) // {
    ${config.services.jellyfin.user}.extraGroups = [ "public_data" ];
  };

  # One-time move from the shared public_data account to per-service users.
  # Runs once before the containers start and stamps itself done; remove the
  # unit once every machine that carries this data has activated it.
  systemd.services.media-permissions-migration = {
    description = "Migrate media library and service state to per-service owners";
    wantedBy = [ "multi-user.target" ];
    requiredBy = [ "container@transmission.service" "container@servarr.service" ];
    before = [ "container@transmission.service" "container@servarr.service" "jellyfin.service" ];
    unitConfig = {
      ConditionPathExists = "!/var/lib/media-permissions-migrated";
      RequiresMountsFor = [ mediaDir "/var/lib" ];
    };
    serviceConfig.Type = "oneshot";
    path = [ pkgs.coreutils pkgs.findutils ];
    script = ''
      set -euo pipefail

      # Library: keep file owners, hand the group to public_data, make
      # directories setgid and everything group-writable.
      chgrp -R public_data ${mediaDir}
      find ${mediaDir} -type d ! -perm -2070 -exec chmod g+rwxs {} +
      find ${mediaDir} -type f ! -perm -0060 -exec chmod g+rw {} +

      # Service state: each service now runs as its own user.
      for svc in ${lib.concatStringsSep " " (lib.attrNames serviceUsers)}; do
        if [ -e "/var/lib/$svc" ]; then
          chown -R "$svc:public_data" "/var/lib/$svc"
        fi
      done

      touch /var/lib/media-permissions-migrated
    '';
  };
}
