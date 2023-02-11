let
  keys = import ../common/ssh.nix;
  systems = keys.systems;
  users = keys.users;
  all = users ++ systems;
in
{
  "email-pw.age".publicKeys = all;
  "iodine.age".publicKeys = all;
  "nextcloud-pw.age".publicKeys = all;
  "pia-login.conf".publicKeys = all;
  "sasl_relay_passwd.age".publicKeys = all;
  "searx.age".publicKeys = all;
  "smb-secrets.age".publicKeys = all;
  "spotifyd.age".publicKeys = all;
  "wolframalpha.age".publicKeys = all;
}
