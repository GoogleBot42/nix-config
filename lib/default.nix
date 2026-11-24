{ lib, ... }:

with lib;

{
  # Passthrough trace for debugging
  pTrace = v: traceSeq v v;
  # find the total sum of a int list
  sum = foldr (x: y: x + y) 0;
  # splits a list of length two into two params then they're passed to a func
  splitPair = f: pair: f (head pair) (last pair);
  # Finds the max value in a list
  maxList = foldr max 0;
  # Sorts a int list. Greatest value first
  sortList = sort (x: y: x > y);
  # Cuts a list in half and returns the two parts in a list
  cutInHalf = l: [ (take (length l / 2) l) (drop (length l / 2) l) ];
  # Splits a list into a list of lists with length cnt
  chunksOf = cnt: l:
    if length l > 0 then
      [ (take cnt l) ] ++ chunksOf cnt (drop cnt l)
    else [ ];
  # same as intersectLists but takes an array of lists to intersect instead of just two
  intersectManyLists = ll: foldr intersectLists (head ll) ll;
  # converts a boolean to a int (c style)
  boolToInt = b: if b then 1 else 0;
  # drops the last element of a list
  dropLast = l: take (length l - 1) l;
  # transposes a matrix
  transpose = ll:
    let
      outerSize = length ll;
      innerSize = length (elemAt ll 0);
    in
    genList (i: genList (j: elemAt (elemAt ll j) i) outerSize) innerSize;
  # attriset recursiveUpdate but for a list of attrisets
  combineAttrs = foldl recursiveUpdate { };
  # visits every single attriset element of an attriset recursively
  # and accumulates the result of every visit in a flat list
  recurisveVisitAttrs = f: set:
    let
      visitor = n: v:
        if isAttrs v then [ (f n v) ] ++ recurisveVisitAttrs f v
        else [ (f n v) ];
    in
    concatLists (map (name: visitor name set.${name}) (attrNames set));
  # merges two lists of the same size (similar to map but both lists are inputs per iteration)
  mergeLists = f: a: imap0 (i: f (elemAt a i));
  map2D = f: ll:
    let
      outerSize = length ll;
      innerSize = length (elemAt ll 0);
      getElem = x: y: elemAt (elemAt ll y) x;
    in
    genList (y: genList (x: f x y (getElem x y)) innerSize) outerSize;

  # Generate a deterministic MAC address from a name
  # Uses locally administered unicast range (02:xx:xx:xx:xx:xx)
  mkMac = name:
    let
      hash = builtins.hashString "sha256" name;
      octets = map (i: builtins.substring i 2 hash) [ 0 2 4 6 8 ];
    in
    "02:${builtins.concatStringsSep ":" octets}";

  # IPv4 network of an address and prefix length, in CIDR form:
  # ipv4Network "192.168.16.1" 24 == "192.168.16.0/24"
  ipv4Network = address: prefixLength:
    let
      octets = map toInt (splitString "." address);
      asInt = foldl (acc: o: acc * 256 + o) 0 octets;
      hostBits = foldl (acc: _: acc * 2) 1 (range 1 (32 - prefixLength));
      network = asInt / hostBits * hostBits;
      octet = shift: toString (mod (network / shift) 256);
    in
    "${concatStringsSep "." (map octet [ 16777216 65536 256 1 ])}/${toString prefixLength}";
}
