{ config, lib, ... }:

let
  system = (import ./ssh.nix).system;
in {
  networking.hosts = {
    # some DNS providers filter local ip results from DNS request
    "172.30.145.180" = [ "s0.zt.neet.dev" ];
    "172.30.109.9" = [ "ponyo.zt.neet.dev" ];
    "172.30.189.212" = [ "ray.zt.neet.dev" ];
  };

  programs.ssh.knownHosts = {
    liza = {
      hostNames = [ "liza" "liza.neet.dev" ];
      publicKey = system.liza;
    };
    ponyo = {
      hostNames = [ "ponyo" "ponyo.neet.dev" "ponyo.zt.neet.dev" ];
      publicKey = system.ponyo;
    };
    ponyo-unlock = {
      hostNames = [ "unlock.ponyo.neet.dev" "cfamr6artx75qvt7ho3rrbsc7mkucmv5aawebwflsfuorusayacffryd.onion" ];
      publicKey = system.ponyo-unlock;
    };
    ray = {
      hostNames = [ "ray" "ray.zt.neet.dev" ];
      publicKey = system.ray;
    };
    s0 = {
      hostNames = [ "s0" "s0.zt.neet.dev" ];
      publicKey = system.s0;
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
}