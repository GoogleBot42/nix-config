{ config, pkgs, lib, ... }:

let
  cfg = config.services.privatebin;
in {
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
    users.groups.privatebin = {};

    services.nginx.enable = true;
    services.nginx.virtualHosts.${cfg.host} = {
      enableACME = true;
      forceSSL = true;
      locations."~ \.php$" = {
        root = lib.mkDerivation {
          name = "privatebin";
          src = lib.fetchFromGitHub {
            owner = "privatebin";
            repo = "privatebin";
            rev = "d65bf02d7819a530c3c2a88f6f9947651fe5258d";
            # sha256 = "";
          };
          installPhase = ''
            cp -ar $src $out
          '';
        };
        extraConfig = ''
          fastcgi_pass  unix:${config.services.phpfpm.pools.privatebin.socket};
          fastcgi_index index.php;
        '';
      };
    };

    systemd.tmpfiles.rules = [
      "d '/var/lib/privatebin' 0750 ${user} ${group} - -"
    ];

    services.phpfpm.pools.privatebin = {                                                                                                                                                                                                             
      user = "privatebin";
      group = "privatebin";
      phpEnv = {
        CONFIG_PATH = "${./conf.php}";
      };
    };
  };
}