let
  keys = import ../common/ssh.nix;
  system = keys.system;
  systemsList = keys.systems;
  usersList = keys.users;
  all = usersList ++ systemsList;

  wireless = [
    system.router
  ] ++ usersList;
in
{
  # TODO: Minimum necessary access to keys

  # email
  "email-pw.age".publicKeys = all;
  "sasl_relay_passwd.age".publicKeys = all;

  # vpn
  "iodine.age".publicKeys = all;
  "pia-login.conf".publicKeys = all;

  # cloud
  "nextcloud-pw.age".publicKeys = all;
  "smb-secrets.age".publicKeys = all;

  # services
  "searx.age".publicKeys = all;
  "spotifyd.age".publicKeys = all;
  "wolframalpha.age".publicKeys = all;

  # hostapd
  "hostapd-pw-experimental-tower.age".publicKeys = wireless;
  "hostapd-pw-CXNK00BF9176.age".publicKeys = wireless;

  # backups
  "backblaze-s3-backups.age".publicKeys = all;
  "restic-password.age".publicKeys = all;
}
