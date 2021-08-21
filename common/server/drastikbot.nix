{ config, pkgs, lib, ... }:

let
  cfg = config.services.drastikbot;
  drastikbot = pkgs.python3Packages.buildPythonApplication rec {
    pname = "drastikbot";
    version = "v2.1";

    format = "other";

    srcs = [
      (pkgs.fetchFromGitHub {
        name = pname;
        owner = "olagood";
        repo = pname;
        rev = version;
        sha256 = "1L8vTE1YEhFWzY5RYb+s5Hb4LrVJNN2leKlZEugEyRU=";
      })
      (pkgs.fetchFromGitHub {
        name = "drastikbot_modules";
        owner = "olagood";
        repo = "drastikbot_modules";
        rev = version;
        sha256 = "w1164FkRkeyWnx6a95WDbwEUvNkNwFWa/6mhKtgVw0c=";
      })
    ];

    sourceRoot = pname;

    nativeBuildInputs = [ pkgs.makeWrapper ];

    installPhase = ''
      cp -r src $out/

      arr=($srcs)
      echo ''${arr[1]}
      cp -r ''${arr[1]}/* $out/irc/modules

      makeWrapper ${pkgs.python3}/bin/python3 $out/drastikbot \
        --prefix PYTHONPATH : ${with pkgs.python3Packages; makePythonPath [requests beautifulsoup4]} \
        --add-flags "$out/drastikbot.py"
    '';
  };
in {
  options.services.drastikbot = {
    enable = lib.mkEnableOption "enable drastikbot";
    user = lib.mkOption {
      type = lib.types.str;
      default = "drastikbot";
      description = ''
        The user drastikbot should run as
      '';
    };
    group = lib.mkOption {
      type = lib.types.str;
      default = "drastikbot";
      description = ''
        The group drastikbot should run as
      '';
    };
    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/drastikbot";
      description = ''
        Path to the drastikbot data directory
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.${cfg.user} = {
        isSystemUser = true;
        group = cfg.group;
        home = cfg.dataDir;
        createHome = true;
    };
    users.groups.${cfg.group} = {};
    systemd.services.drastikbot = {
      enable = true;
      after = ["network.target"];
      wantedBy = ["multi-user.target"];
      serviceConfig.ExecStart = "${drastikbot}/drastikbot -c ${cfg.dataDir}";
      serviceConfig.User = cfg.user;
      serviceConfig.Group = cfg.group;
      preStart = ''
        mkdir -p ${cfg.dataDir}
        chown ${cfg.user} ${cfg.dataDir}
      '';
    };
  };
}