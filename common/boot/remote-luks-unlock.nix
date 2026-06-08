{ config, pkgs, lib, ... }:

# TODO: use tailscale instead of tor https://gist.github.com/antifuchs/e30d58a64988907f282c82231dde2cbc

let
  cfg = config.remoteLuksUnlock;
in
{
  options.remoteLuksUnlock = {
    enable = lib.mkEnableOption "enable luks root remote decrypt over ssh/tor";
    enableTorUnlock = lib.mkOption {
      type = lib.types.bool;
      default = cfg.enable;
      description = "Make machine accessable over tor for ssh boot unlock";
    };
    sshHostKeys = lib.mkOption {
      type = lib.types.listOf (lib.types.either lib.types.str lib.types.path);
      default = [
        "/secret/ssh_host_rsa_key"
        "/secret/ssh_host_ed25519_key"
      ];
    };
    sshAuthorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = lib.unique (
        config.users.users.root.openssh.authorizedKeys.keys
        ++ config.users.users.googlebot.openssh.authorizedKeys.keys
      );
    };
    onionConfig = lib.mkOption {
      type = lib.types.path;
      default = /secret/onion;
    };
    kernelModules = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "e1000" "e1000e" "virtio_pci" "r8169" ];
    };
  };

  config = lib.mkIf cfg.enable {
    # Unlock LUKS disk over ssh
    boot.initrd.network.enable = true;
    boot.initrd.kernelModules = cfg.kernelModules;
    boot.initrd.network.ssh = {
      enable = true;
      port = 22;
      hostKeys = cfg.sshHostKeys;
      authorizedKeys = cfg.sshAuthorizedKeys;
    };

    # Use systemd-tty-ask-password-agent for interactive LUKS passphrase entry over SSH
    boot.initrd.systemd.users.root.shell = "/bin/systemd-tty-ask-password-agent --watch";

    # Tor hidden service for remote unlock over onion
    boot.initrd.secrets = lib.mkIf cfg.enableTorUnlock {
      "/etc/tor/onion/bootup" = cfg.onionConfig;
    };

    boot.initrd.systemd.storePaths = lib.mkIf cfg.enableTorUnlock [
      "${pkgs.tor}/bin/tor"
      "${pkgs.haveged}/bin/haveged"
    ];

    boot.initrd.systemd.services.tor-unlock = lib.mkIf cfg.enableTorUnlock {
      description = "Tor Hidden Service for Boot Unlock";
      wantedBy = [ "initrd.target" ];
      after = [ "network.target" "sshd.service" ];
      wants = [ "network.target" ];

      unitConfig.DefaultDependencies = false;

      serviceConfig = {
        Type = "forking";
        RemainAfterExit = true;
      };

      script =
        let
          torRc = pkgs.writeText "tor.rc" ''
            DataDirectory /etc/tor
            SOCKSPort 127.0.0.1:9050 IsolateDestAddr
            SOCKSPort 127.0.0.1:9063
            HiddenServiceDir /etc/tor/onion/bootup
            HiddenServicePort 22 127.0.0.1:22
          '';
        in
        ''
          # Fix permissions for tor
          chmod -R 700 /etc/tor

          # Ensure loopback is up
          ip a a 127.0.0.1/8 dev lo 2>/dev/null || true
          ip link set lo up

          # Start haveged for entropy
          ${pkgs.haveged}/bin/haveged -F &

          # Verify and start tor
          ${pkgs.tor}/bin/tor -f ${torRc} --verify-config
          ${pkgs.tor}/bin/tor -f ${torRc} &
        '';
    };
  };
}
