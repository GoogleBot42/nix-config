{ config, lib, pkgs, ... }:

{
  programs.ssh.knownHosts = lib.filterAttrs (n: v: v != null) (lib.concatMapAttrs
    (host: cfg: {
      ${host} = {
        hostNames = cfg.hostNames;
        publicKey = cfg.hostKey;
      };
      "${host}-remote-unlock" =
        if cfg.remoteUnlock != null then {
          hostNames = builtins.filter (h: h != null) [ cfg.remoteUnlock.clearnetHost cfg.remoteUnlock.onionHost ];
          publicKey = cfg.remoteUnlock.hostKey;
        } else null;
    })
    config.machines.hosts);

  # prebuilt cmds for easy ssh LUKS unlock
  environment.shellAliases =
    let
      unlockHosts = unlockType: lib.concatMapAttrs
        (host: cfg:
          if cfg.remoteUnlock != null && cfg.remoteUnlock.${unlockType} != null then {
            ${host} = cfg.remoteUnlock.${unlockType};
          } else { })
        config.machines.hosts;
    in
    lib.concatMapAttrs (host: addr: { "unlock-over-tor_${host}" = "torsocks ssh root@${addr}"; }) (unlockHosts "onionHost")
    //
    lib.concatMapAttrs (host: addr: { "unlock_${host}" = "ssh root@${addr}"; }) (unlockHosts "clearnetHost");

  # TODO: Old ssh keys I will remove some day...
  machines.ssh.userKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMVR/R3ZOsv7TZbICGBCHdjh1NDT8SnswUyINeJOC7QG"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE0dcqL/FhHmv+a1iz3f9LJ48xubO7MZHy35rW9SZOYM"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHSkKiRUUmnErOKGx81nyge/9KqjkPh8BfDk0D3oP586" # nat
  ];
}
