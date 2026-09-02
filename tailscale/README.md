# Tailscale ACL

`acl.hujson` is the tailnet policy file for `koi-bebop.ts.net`. It is not
NixOS configuration: nothing in the flake reads it. It lives here, next to
`dns/`, because it is fleet-wide declarative state that is applied by CI
rather than by a machine deploy.

The `Sync Tailscale ACL` workflow (`.gitea/workflows/tailscale-acl.yaml`)
tests and then applies this file with `tailscale/gitops-acl-action` on every
push to `master` that touches it, and on manual dispatch. It does not run for
pull requests: the OAuth secrets are not available there, so a PR run could
only ever skip.
