# mounts the samba share on s0 over zeroteir

{ config, lib, ... }:

let
  cfg = config.services.mount-samba;

  # prevents hanging on network split
  network_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s,nostrictsync,cache=loose,handlecache,handletimeout=30000,rwpidforward,mapposix,soft,resilienthandles,echo_interval=10,noblocksend";

  user_opts = "uid=${toString config.users.users.googlebot.uid},file_mode=0660,dir_mode=0770,user";
  auth_opts = "credentials=/run/agenix/smb-secrets";
  version_opts = "vers=2.1";

  opts = "${network_opts},${user_opts},${version_opts},${auth_opts}";
in {
  options.services.mount-samba = {
    enable = lib.mkEnableOption "enable mounting samba shares";
  };

  config = lib.mkIf (cfg.enable && config.services.zerotierone.enable) {
    fileSystems."/mnt/public" = {
        device = "//s0.zt.neet.dev/public";
        fsType = "cifs";
        options = [ opts ];
    };

    fileSystems."/mnt/private" = {
        device = "//s0.zt.neet.dev/googlebot";
        fsType = "cifs";
        options = [ opts ];
    };

    age.secrets.smb-secrets.file = ../../secrets/smb-secrets.age;
  };
}