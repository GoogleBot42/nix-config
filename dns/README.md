DNS management
==============

Source of truth:
- dns/domains.nix: inventory of DigitalOcean-managed zones
- dns/zones.nix: declarative records reviewed in PRs

Bootstrap/import flow:
1. Add or remove managed domains in dns/domains.nix.
2. Run the "Import DigitalOcean DNS" workflow from Gitea.
3. The workflow snapshots live DNS from DigitalOcean into dns/zones.nix on a branch and opens a PR against stage.
4. Review/merge the PR.

Required Gitea Actions secrets:
- DIGITALOCEAN_TOKEN: token with read access to domain records
- PUSH_TOKEN: token able to push branches and create pull requests in this repo
