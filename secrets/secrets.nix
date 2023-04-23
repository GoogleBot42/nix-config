let
  lib = (import <nixpkgs> { }).lib;
  sshKeys = (import ../common/machine-info/moduleless.nix { }).machines.ssh;

  # add userkeys to all roles so that I can r/w the secrets from my personal computers
  roles = lib.mapAttrs (role: hosts: hosts ++ sshKeys.userKeys) sshKeys.hostKeysByRole;

  # nobody is using this secret but I still need to be able to r/w it
  nobody = sshKeys.userKeys;
in

with roles;

{
  # email
  "hashed-email-pw.age".publicKeys = email-server;
  "cris-hashed-email-pw.age".publicKeys = email-server;
  "sasl_relay_passwd.age".publicKeys = email-server;
  "hashed-robots-email-pw.age".publicKeys = email-server;
  "robots-email-pw.age".publicKeys = gitea;

  # vpn
  "iodine.age".publicKeys = iodine;
  "pia-login.age".publicKeys = pia;

  # cloud
  "nextcloud-pw.age".publicKeys = nextcloud;
  "smb-secrets.age".publicKeys = personal;

  # services
  "searx.age".publicKeys = nobody;
  "spotifyd.age".publicKeys = personal;
  "wolframalpha.age".publicKeys = dailybot;

  # hostapd
  "hostapd-pw-experimental-tower.age".publicKeys = wireless;
  "hostapd-pw-CXNK00BF9176.age".publicKeys = wireless;

  # backups
  "backblaze-s3-backups.age".publicKeys = personal ++ server;
  "restic-password.age".publicKeys = personal ++ server;
}
