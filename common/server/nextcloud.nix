{ config, pkgs, lib, ... }:


let
  cfg = config.services.nextcloud;
in {
  config = lib.mkIf cfg.enable {
    services.nextcloud = {
      https = true;
      package = pkgs.nextcloud23;
      hostName = "neet.cloud";
      config.dbtype = "sqlite";
      config.adminuser = "jeremy";
      config.adminpassFile = "/run/agenix/nextcloud-pw";
      autoUpdateApps.enable = true;
    };
    age.secrets.nextcloud-pw = {
      file = ../../secrets/nextcloud-pw.age;
      owner = "nextcloud";
    };
    services.nginx.virtualHosts.${config.services.nextcloud.hostName} = {
      enableACME = true;
      forceSSL = true;
    };
  };
}