{ config, pkgs, ... }:

let
  zerobin_config = pkgs.writeText "zerobin-config.py" ''
    PASTE_FILES_ROOT = "/var/lib/zerobin"
  '';
in {
#  services.zerobin = {
#    enable = true;
#    listenAddress = "0.0.0.0";
#    listenPort = 9002;
#  };

  nixpkgs.config.packageOverrides = pkgs:
    with pkgs;
  {
    python38Packages.cherrypy = python38Packages.cherrypy.overrideAttrs (attrs: rec {
      src = fetchPypi {
        pname = "CherryPy";
        version = "8.9.1";
        sha256 = "";
      };
    });
  };

  services.nginx.virtualHosts."paste.neet.cloud" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://localhost:9002";
    };
  };

  users.users.zerobin = {
    isSystemUser = true;
    group = "zerobin";
    home = "/var/lib/zerobin";
    createHome = true;
  };
  users.groups.zerobin = {};

  systemd.services.zerobin = {
    enable = true;
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig.ExecStart = "${pkgs.python38Packages.zerobin}/bin/zerobin 0.0.0.0 9002 false zerobin zerobin ${zerobin_config}";
    serviceConfig.PrivateTmp="yes";
    serviceConfig.User = "zerobin";
    serviceConfig.Group = "zerobin";
    preStart = ''
      mkdir -p "/var/lib/zerobin"
      chown zerobin "/var/lib/zerobin"
    '';
  };
}
