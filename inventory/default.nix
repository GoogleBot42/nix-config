# Static service-inventory site generated from this flake: every machine's
# nginx virtual hosts, firewall, enabled services, containers, workspaces,
# the managed DNS zones and the Tailscale ACL, in one page plus a JSON file
# (inventory.json) for tooling.
{ pkgs
, lib
, nixosConfigurations
, zones
, aclFile
, revision ? "unknown"
, nixpkgsRevision ? "unknown"
}:

let
  data = import ./extract.nix { inherit lib nixosConfigurations zones; };
  json = pkgs.writeText "inventory-data.json" (builtins.toJSON (data // {
    meta = {
      inherit revision;
      inherit nixpkgsRevision;
      nixosRelease = lib.trivial.release;
    };
  }));
in
pkgs.runCommand "service-inventory"
{
  nativeBuildInputs = [ pkgs.jq pkgs.perl ];
} ''
  mkdir -p $out

  # tailscale/acl.hujson -> JSON: drop // comments, then trailing commas.
  perl -pe 's{^\s*//.*$}{}; s{\s+//.*$}{}' ${aclFile} \
    | perl -0pe 's/,(\s*[\]}])/$1/g' \
    | jq -c . > $out/acl.json

  jq -c --slurpfile acl $out/acl.json '. + { tailscaleAcl: $acl[0] }' ${json} > $out/inventory.json

  { printf 'window.INVENTORY = '; cat $out/inventory.json; printf ';\n'; } > $out/inventory.js
  cp ${./index.html} $out/index.html
''
