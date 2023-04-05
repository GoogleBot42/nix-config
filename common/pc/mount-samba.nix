# mounts the samba share on s0 over tailscale

{ config, lib, pkgs, ... }:

let
  cfg = config.services.mount-samba;

  # prevents hanging on network split and other similar niceties to ensure a stable connection
  network_opts = "nostrictsync,cache=strict,handlecache,handletimeout=30000,rwpidforward,mapposix,soft,resilienthandles,echo_interval=10,noblocksend,fsc";

  systemd_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";
  user_opts = "uid=${toString config.users.users.googlebot.uid},file_mode=0660,dir_mode=0770,user";
  auth_opts = "sec=ntlmv2i,credentials=/run/agenix/smb-secrets";
  version_opts = "vers=3.1.1";

  opts = "${systemd_opts},${network_opts},${user_opts},${version_opts},${auth_opts}";
in
{
  options.services.mount-samba = {
    enable = lib.mkEnableOption "enable mounting samba shares";
  };

  config = lib.mkIf (cfg.enable && config.services.tailscale.enable) {
    fileSystems."/mnt/public" = {
      device = "//s0.koi-bebop.ts.net/public";
      fsType = "cifs";
      options = [ opts ];
    };

    fileSystems."/mnt/private" = {
      device = "//s0.koi-bebop.ts.net/googlebot";
      fsType = "cifs";
      options = [ opts ];
    };

    age.secrets.smb-secrets.file = ../../secrets/smb-secrets.age;

    environment.shellAliases = {
      # remount storage
      remount_public = "sudo systemctl restart mnt-public.mount";
      remount_private = "sudo systemctl restart mnt-private.mount";

      # Encrypted Vault
      vault_unlock = "${pkgs.gocryptfs}/bin/gocryptfs /mnt/private/.vault/ /mnt/vault/";
      vault_lock = "umount /mnt/vault/";
    };
  };
}
