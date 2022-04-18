let
  keys = import ../common/ssh.nix;
  systems = keys.systems;
  users = keys.users;
  all = users ++ systems;
in
{
  "searx.age".publicKeys = all;
  "pia-login.conf".publicKeys = all;
  "peertube-init.age".publicKeys = all;
  "peertube-db-pw.age".publicKeys = all;
  "peertube-redis-pw.age".publicKeys = all;
  "peertube-smtp.age".publicKeys = all;
  "email-pw.age".publicKeys = all;
  "nextcloud-pw.age".publicKeys = all;
  "iodine.age".publicKeys = all;
  "spotifyd.age".publicKeys = all;
  "wolframalpha.age".publicKeys = all;
  "cloudflared-navidrome.json.age".publicKeys = all;
}
