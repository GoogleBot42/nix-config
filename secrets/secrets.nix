let
  lib = (import <nixpkgs> { }).lib;
  sshKeys = (import ../common/machine-info/moduleless.nix { }).machines.ssh;

  # add userkeys to all roles so that I can r/w the secrets from my personal computers
  roles = lib.mapAttrs (role: hosts: hosts ++ sshKeys.userKeys) sshKeys.hostKeysByRole;

  # nobody is using this secret but I still need to be able to r/w it
  nobody = sshKeys.userKeys;

  # For secrets that all machines need to know
  everyone = roles.personal ++ roles.server;
in

with roles;

{
  # email
  "hashed-email-pw.age".publicKeys = email-server;
  "cris-hashed-email-pw.age".publicKeys = email-server;
  "sasl_relay_passwd.age".publicKeys = email-server;
  "hashed-robots-email-pw.age".publicKeys = email-server;
  "robots-email-pw.age".publicKeys = gitea ++ outline;

  # nix binary cache
  # public key: s0.koi-bebop.ts.net:OjbzD86YjyJZpCp9RWaQKANaflcpKhtzBMNP8I2aPUU=
  "binary-cache-private-key.age".publicKeys = binary-cache;

  # attic binary cache
  "atticd-credentials.age".publicKeys = binary-cache;
  "attic-netrc.age".publicKeys = everyone;

  # vpn
  "pia-login.age".publicKeys = pia;

  # cloud
  "nextcloud-pw.age".publicKeys = nextcloud;
  "whiteboard-server-jwt-secret.age".publicKeys = nextcloud;
  "smb-secrets.age".publicKeys = personal ++ media-center;

  # services
  "wolframalpha.age".publicKeys = dailybot;
  "linkwarden-environment.age".publicKeys = linkwarden;

  # backups
  "backblaze-s3-backups.age".publicKeys = personal ++ server;
  "restic-password.age".publicKeys = personal ++ server;

  # gitea actions runner
  "gitea-actions-runner-token.age".publicKeys = gitea-actions-runner;

  # Librechat
  "librechat-env-file.age".publicKeys = librechat;

  # For ACME DNS Challenge
  "digitalocean-dns-credentials.age".publicKeys = dns-challenge;

  # Frigate (DVR)
  "frigate-credentials.age".publicKeys = frigate;

  # zigbee2mqtt secrets
  "zigbee2mqtt.yaml.age".publicKeys = zigbee;

  # Sonarr and Radarr secrets
  "radarr-api-key.age".publicKeys = media-server;
  "sonarr-api-key.age".publicKeys = media-server;
}
