{ config, lib, pkgs, ... }:

{
  config = lib.mkIf config.services.samba.enable {
    services.samba = {
      openFirewall = true;
      package = pkgs.sambaFull; # printer sharing
      securityType = "user";

      # should this be on?
      nsswins = true;

      extraConfig = ''
        workgroup = HOME
        server string = smbnix
        netbios name = smbnix
        security = user 
        use sendfile = yes
        min protocol = smb2
        guest account = nobody
        map to guest = bad user

        # printing
        load printers = yes
        printing = cups
        printcap name = cups

        # encryption
        server smb encrypt = desired

        # gotta go fast https://wiki.archlinux.org/title/Samba#Improve_throughput
        server multi channel support = yes
        deadtime = 30
        use sendfile = yes
        min receivefile size = 16384
        aio read size = 1
        aio write size = 1
        socket options = IPTOS_LOWDELAY TCP_NODELAY IPTOS_THROUGHPUT SO_RCVBUF=131072 SO_SNDBUF=131072
      '';

      shares = {
        public = {
          path = "/data/samba/Public";
          browseable = "yes";
          "read only" = "no";
          "guest ok" = "yes";
          "create mask" = "0644";
          "directory mask" = "0755";
          "force user" = "public_data";
          "force group" = "public_data";
        };
        private = {
          path = "/data/samba/Private";
          browseable = "yes";
          "read only" = "no";
          "guest ok" = "no";
          "create mask" = "0644";
          "directory mask" = "0755";
          "force user" = "googlebot";
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
    services.avahi.nssmdns = true;

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
  };
}