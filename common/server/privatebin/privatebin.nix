{ config, pkgs, lib, ... }:

let
  cfg = config.services.privatebin;
  privateBinSrc = pkgs.stdenv.mkDerivation {
    name = "privatebin";
    src = pkgs.fetchFromGitHub {
      owner = "privatebin";
      repo = "privatebin";
      rev = "d65bf02d7819a530c3c2a88f6f9947651fe5258d";
      sha256 = "7ttAvEDL1ab0cUZcqZzXFkXwB2rF2t4eNpPxt48ap94=";
    };
    installPhase = ''
      cp -ar $src $out
    '';
  };
in
{
  options.services.privatebin = {
    enable = lib.mkEnableOption "enable privatebin";
    host = lib.mkOption {
      type = lib.types.str;
      example = "example.com";
    };
  };

  config = lib.mkIf cfg.enable {

    users.users.privatebin = {
      description = "privatebin service user";
      group = "privatebin";
      isSystemUser = true;
    };
    users.groups.privatebin = { };

    services.nginx.enable = true;
    services.nginx.virtualHosts.${cfg.host} = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        root = privateBinSrc;
        index = "index.php";
      };
      locations."~ \.php$" = {
        root = privateBinSrc;
        extraConfig = ''
          fastcgi_pass  unix:${config.services.phpfpm.pools.privatebin.socket};
          fastcgi_index index.php;
        '';
      };
    };

    systemd.tmpfiles.rules = [
      "d '/var/lib/privatebin' 0750 privatebin privatebin - -"
    ];

    services.phpfpm.pools.privatebin = {
      user = "privatebin";
      group = "privatebin";
      phpEnv = {
        CONFIG_PATH = "${./conf.php}";
      };
      settings = {
        pm = "dynamic";
        "listen.owner" = config.services.nginx.user;
        "pm.max_children" = 5;
        "pm.start_servers" = 2;
        "pm.min_spare_servers" = 1;
        "pm.max_spare_servers" = 3;
        "pm.max_requests" = 500;
      };
    };
  };
}
