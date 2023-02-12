{ config, lib, ... }:

with builtins;

let
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
in {
  networking.hosts = {
    # some DNS providers filter local ip results from DNS request
    "172.30.145.180" = [ "s0.zt.neet.dev" ];
    "172.30.109.9" = [ "ponyo.zt.neet.dev" ];
    "172.30.189.212" = [ "ray.zt.neet.dev" ];
  };

  programs.ssh.knownHosts = {
    liza = {
      hostNames = [ "liza" "mail.neet.dev" ];
      publicKey = system.liza;
    };
    liza-unlock = {
      hostNames = [ unlock-onion-hosts.liza ];
      publicKey = system.liza-unlock;
    };
    ponyo = {
      hostNames = [ "ponyo" "ponyo.neet.dev" "ponyo.zt.neet.dev" "git.neet.dev" ];
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
      hostNames = [ "ray" "ray.zt.neet.dev" ];
      publicKey = system.ray;
    };
    s0 = {
      hostNames = [ "s0" "s0.zt.neet.dev" ];
      publicKey = system.s0;
    };
    s0-unlock = {
      hostNames = [ unlock-onion-hosts.s0 ];
      publicKey = system.s0-unlock;
    };
    n1 = {
      hostNames = [ "n1" ];
      publicKey = system.n1;
    };
    n2 = {
      hostNames = [ "n2" ];
      publicKey = system.n2;
    };
    n3 = {
      hostNames = [ "n3" ];
      publicKey = system.n3;
    };
    n4 = {
      hostNames = [ "n4" ];
      publicKey = system.n4;
    };
    n5 = {
      hostNames = [ "n5" ];
      publicKey = system.n5;
    };
    n6 = {
      hostNames = [ "n6" ];
      publicKey = system.n6;
    };
    n7 = {
      hostNames = [ "n7" ];
      publicKey = system.n7;
    };
  };

  # prebuilt cmds for easy ssh LUKS unlock
  environment.shellAliases =
    let
      # TODO: remove when all systems are updated to new enough nixpkgs
      concatMapAttrs =
        f: with lib; flip pipe [ (mapAttrs f) attrValues (foldl' mergeAttrs { }) ];
    in
      concatMapAttrs (host: addr: {"unlock-over-tor_${host}" = "torsocks ssh root@${addr}";}) unlock-onion-hosts
        //
      concatMapAttrs (host: addr: {"unlock_${host}" = "torsocks ssh root@${addr}";}) unlock-clearnet-hosts;
}