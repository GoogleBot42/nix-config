{ config, lib, ... }:

with builtins;

let
  # TODO: remove when all systems are updated to new enough nixpkgs
  concatMapAttrs =
    f: with lib; flip pipe [ (mapAttrs f) attrValues (foldl' mergeAttrs { }) ];

  system = (import ../ssh.nix).system;

  # hostnames that resolve on clearnet for LUKS unlocking
  unlock-clearnet-hosts = {
    ponyo = "unlock.ponyo.neet.dev";
    s0 = "s0";
  };

  # hostnames that resolve on tor for LUKS unlocking
  unlock-onion-hosts = {
    liza = "5synsrjgvfzywruomjsfvfwhhlgxqhyofkzeqt2eisyijvjvebnu2xyd.onion";
    router = "jxx2exuihlls2t6ncs7rvrjh2dssubjmjtclwr2ysvxtr4t7jv55xmqd.onion";
    ponyo = "cfamr6artx75qvt7ho3rrbsc7mkucmv5aawebwflsfuorusayacffryd.onion";
    s0 = "r3zvf7f2ppaeithzswigma46pajt3hqytmkg3rshgknbl3jbni455fqd.onion";
  };
in
{
  programs.ssh.knownHosts = {
    ponyo = {
      hostNames = [ "ponyo" "ponyo.neet.dev" "git.neet.dev" ];
      publicKey = system.ponyo;
    };
    ponyo-unlock = {
      hostNames = [ unlock-clearnet-hosts.ponyo unlock-onion-hosts.ponyo ];
      publicKey = system.ponyo-unlock;
    };
    router = {
      hostNames = [ "router" "192.168.1.228" ];
      publicKey = system.router;
    };
    router-unlock = {
      hostNames = [ unlock-onion-hosts.router ];
      publicKey = system.router-unlock;
    };
    ray = {
      hostNames = [ "ray" ];
      publicKey = system.ray;
    };
    s0 = {
      hostNames = [ "s0" ];
      publicKey = system.s0;
    };
    s0-unlock = {
      hostNames = [ unlock-onion-hosts.s0 ];
      publicKey = system.s0-unlock;
    };
  };

  # prebuilt cmds for easy ssh LUKS unlock
  environment.shellAliases =
    concatMapAttrs (host: addr: { "unlock-over-tor_${host}" = "torsocks ssh root@${addr}"; }) unlock-onion-hosts
    //
    concatMapAttrs (host: addr: { "unlock_${host}" = "ssh root@${addr}"; }) unlock-clearnet-hosts;
}
