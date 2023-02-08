{ lib, config, pkgs, ... }:

with lib;

let
  cfg = config.services.pia;
in {
  imports = [
    ./pia.nix
  ];

  options.services.pia = {
    enable = lib.mkEnableOption "Enable PIA Client";

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/pia";
      description = ''
        Path to the pia data directory
      '';
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "root";
      description = ''
        The user pia should run as
      '';
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "piagrp";
      description = ''
        The group pia should run as
      '';
    };

    users = mkOption {
      type = with types; listOf str;
      default = [];
      description = ''
        Usernames to be added to the "spotifyd" group, so that they
        can start and interact with the userspace daemon.
      '';
    };
  };

  config = mkIf cfg.enable {

    # users.users.${cfg.user} =
    # if cfg.user == "pia" then {
    #   isSystemUser = true;
    #   group = cfg.group;
    #   home = cfg.dataDir;
    #   createHome = true;
    # }
    # else {};
    users.groups.${cfg.group}.members = cfg.users;

    systemd.services.pia-daemon = {
      enable = true;
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig.ExecStart = "${pkgs.pia-daemon}/bin/pia-daemon";
      serviceConfig.PrivateTmp="yes";
      serviceConfig.User = cfg.user;
      serviceConfig.Group = cfg.group;
      preStart = ''
        mkdir -p ${cfg.dataDir}
        chown ${cfg.user}:${cfg.group} ${cfg.dataDir}
      '';
    };

  };
}