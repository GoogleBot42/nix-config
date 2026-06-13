# Managed DNS source of truth.
#
# Bootstrap flow:
#   1. Keep the domain inventory in dns/domains.nix.
#   2. Run the "Import DigitalOcean DNS" Gitea workflow to snapshot the live
#      records into this file.
#   3. Review the generated PR, merge it, and let the apply workflow keep
#      DigitalOcean in sync on future merges.
#
# This file is intentionally simple Nix data so future PRs can edit it directly.
{
  av1.zip = {
    nameservers = [ ];
    records = [ ];
  };
  bsd.ninja = {
    nameservers = [ ];
    records = [ ];
  };
  bsd.rocks = {
    nameservers = [ ];
    records = [ ];
  };
  neet.cloud = {
    nameservers = [ ];
    records = [ ];
  };
  neet.dev = {
    nameservers = [ ];
    records = [ ];
  };
  neet.space = {
    nameservers = [ ];
    records = [ ];
  };
  runyan.org = {
    nameservers = [ ];
    records = [ ];
  };
  runyan.rocks = {
    nameservers = [ ];
    records = [ ];
  };
  tar.ninja = {
    nameservers = [ ];
    records = [ ];
  };
  thunderhex.com = {
    nameservers = [ ];
    records = [ ];
  };
  zstd.zip = {
    nameservers = [ ];
    records = [ ];
  };
}
