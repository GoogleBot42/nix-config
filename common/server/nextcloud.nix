{ config, pkgs, lib, ... }:


let
  cfg = config.services.nextcloud;
in
{
  config = lib.mkIf cfg.enable {
    services.nextcloud = {
      https = true;
      package = pkgs.nextcloud30;
      hostName = "neet.cloud";
      config.dbtype = "sqlite";
      config.adminuser = "jeremy";
      config.adminpassFile = "/run/agenix/nextcloud-pw";
      autoUpdateApps.enable = true;
      extraApps = with config.services.nextcloud.package.packages.apps; {
        # Want
        inherit end_to_end_encryption mail spreed;

        # Might use
        inherit bookmarks calendar cookbook deck memories onlyoffice qownnotesapi;

        # Try out
        # inherit maps music news notes phonetrack polls forms;
      };
      extraAppsEnable = true;
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
  };
}
