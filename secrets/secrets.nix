let
  keys = import ../common/ssh.nix;
  systems = keys.systems;
  users = keys.users;
  all = users ++ systems;
in
{
  "searx.age".publicKeys = all;
  "pia-login.conf".publicKeys = all;
}