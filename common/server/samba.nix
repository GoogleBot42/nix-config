{ config, lib, pkgs, ... }:

{
  config = lib.mkIf config.services.samba.enable {
    services.samba = {
      openFirewall = true;
      package = pkgs.sambaFull; # printer sharing

      # should this be on?
      nsswins = true;

      settings = {
        global = {
          security = "user";
          workgroup = "HOME";
          "server string" = "smbnix";
          "netbios name" = "smbnix";
          "use sendfile" = "yes";
          "min protocol" = "smb2";
          "guest account" = "nobody";
          "map to guest" = "bad user";

          # printing
          "load printers" = "yes";
          printing = "cups";
          "printcap name" = "cups";

          "hide files" = "/.nobackup/.DS_Store/._.DS_Store/";
        };
        public = {
          path = "/data/samba/Public";
          browseable = "yes";
          "read only" = "no";
          "guest ok" = "no";
          "create mask" = "0644";
          "directory mask" = "0755";
          "force user" = "public_data";
          "force group" = "public_data";
        };
        googlebot = {
          path = "/data/samba/googlebot";
          browseable = "yes";
          "read only" = "no";
          "guest ok" = "no";
          "valid users" = "googlebot";
          "create mask" = "0644";
          "directory mask" = "0755";
          "force user" = "googlebot";
          "force group" = "users";
        };
        cris = {
          path = "/data/samba/cris";
          browseable = "yes";
          "read only" = "no";
          "guest ok" = "no";
          "valid users" = "cris";
          "create mask" = "0644";
          "directory mask" = "0755";
          "force user" = "root";
          "force group" = "users";
        };
        printers = {
          comment = "All Printers";
          path = "/var/spool/samba";
          public = "yes";
          browseable = "yes";
          # to allow user 'guest account' to print.
          "guest ok" = "yes";
          writable = "no";
          printable = "yes";
          "create mode" = 0700;
        };
      };
    };

    # backups
    backup.group."samba".paths = [
      config.services.samba.settings.googlebot.path
      config.services.samba.settings.cris.path
      config.services.samba.settings.public.path
    ];

    # Windows discovery of samba server
    services.samba-wsdd = {
      enable = true;

      # are these needed?
      workgroup = "HOME";
      hoplimit = 3;
      discovery = true;
    };
    networking.firewall.allowedTCPPorts = [ 5357 ];
    networking.firewall.allowedUDPPorts = [ 3702 ];

    # Printer discovery
    # (is this needed?)
    services.avahi.enable = true;
    services.avahi.nssmdns4 = true;

    # printer sharing
    systemd.tmpfiles.rules = [
      "d /var/spool/samba 1777 root root -"
    ];

    users.groups.public_data.gid = 994;
    users.users.public_data = {
      isSystemUser = true;
      group = "public_data";
      uid = 994;
    };
    users.users.googlebot.extraGroups = [ "public_data" ];

    # samba user for share
    users.users.cris.isSystemUser = true;
    users.users.cris.group = "cris";
    users.groups.cris = { };
  };
}
