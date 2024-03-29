{ config, pkgs, lib, ... }:

let
  cfg = config.services.radio;
  radioPackage = config.inputs.radio.packages.${config.currentSystem}.radio;
in
{
  options.services.radio = {
    enable = lib.mkEnableOption "enable radio";
    user = lib.mkOption {
      type = lib.types.str;
      default = "radio";
      description = ''
        The user radio should run as
      '';
    };
    group = lib.mkOption {
      type = lib.types.str;
      default = "radio";
      description = ''
        The group radio should run as
      '';
    };
    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/radio";
      description = ''
        Path to the radio data directory
      '';
    };
    host = lib.mkOption {
      type = lib.types.str;
      description = ''
        Domain radio is hosted on
      '';
    };
    nginx = lib.mkEnableOption "enable nginx";
  };

  config = lib.mkIf cfg.enable {
    services.icecast = {
      enable = true;
      hostname = cfg.host;
      mount = "stream.mp3";
      fallback = "fallback.mp3";
    };

    services.nginx.virtualHosts.${cfg.host} = lib.mkIf cfg.nginx {
      enableACME = true;
      forceSSL = true;
      locations."/".root = config.inputs.radio-web;
    };

    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.dataDir;
      createHome = true;
    };
    users.groups.${cfg.group} = { };
    systemd.services.radio = {
      enable = true;
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig.ExecStart = "${radioPackage}/bin/radio ${config.services.icecast.listen.address}:${toString config.services.icecast.listen.port} ${config.services.icecast.mount} 5500";
      serviceConfig.User = cfg.user;
      serviceConfig.Group = cfg.group;
      serviceConfig.WorkingDirectory = cfg.dataDir;
      preStart = ''
        mkdir -p ${cfg.dataDir}
        chown ${cfg.user} ${cfg.dataDir}
      '';
    };
  };
}
