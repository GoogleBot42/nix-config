DNS management
==============

Source of truth:
- dns/domains.nix: inventory of DigitalOcean-managed zones
- dns/zones.nix: declarative records reviewed in PRs

Bootstrap/import flow:
1. Add or remove managed domains in dns/domains.nix.
2. Run the "Import DigitalOcean DNS" workflow from Gitea.
3. The workflow snapshots live DNS from DigitalOcean into dns/zones.nix on a branch and opens a PR against master.
4. Review/merge the PR.
5. Normal DNS PRs validate by building the `.#dnscontrolConfig` flake output and showing a before/after diff of the rendered config relative to the PR base.
6. Live DigitalOcean changes are never applied automatically by PR or push workflows. Run the "Preview DigitalOcean DNS" workflow when you want to inspect the live provider diff for the current master branch, then run the separate "Push DigitalOcean DNS" workflow only after that preview has been reviewed.

Safety gates:
- PRs and master pushes build the `.#dnscontrolConfig` flake output without provider credentials.
- Pull request runs also print a before/after diff of the rendered dnscontrol config, so reviewers can inspect the proposed DNSControl changes without DigitalOcean API access. During the renderer-introduction PR, the workflow uses the PR's renderer to render the base branch's existing dns/zones.nix, so unchanged DNS values show as a no-op instead of as a wholly new generated file.
- Gitea 1.26.x does not provide a GitHub-style protected environment approval gate for Actions jobs; the documented Gitea Actions compatibility table says `jobs.<job_id>.environment` is ignored by Gitea Actions.
- Because there is no enforced mid-workflow approval pause, live deployment stays as two explicit manual workflows: first run "Preview DigitalOcean DNS" and review the `dnscontrol preview` log, then run "Push DigitalOcean DNS" if the preview is acceptable.
- The push operation re-renders the config from master immediately before running `dnscontrol push`, so it applies the current reviewed master branch rather than PR code or a local checkout.

After bootstrap:
- dns/zones.nix can be hand-maintained as ordinary Nix, including local let-bound variables/helpers to reduce repetition.
- Re-running the import workflow will regenerate a flat snapshot and overwrite those manual cleanups.

Required Gitea Actions secrets:
- DIGITALOCEAN_TOKEN: token with read/write access to domain records for preview/apply
- PUSH_TOKEN: token able to push branches and create pull requests in this repo

Manual live-apply procedure:
1. In Gitea, run the "Preview DigitalOcean DNS" workflow on master.
2. Open the completed workflow run and review the `dnscontrol preview` output.
3. If the preview is acceptable, run the separate "Push DigitalOcean DNS" workflow on master.
4. Review the push workflow logs to confirm `dnscontrol push` completed successfully.

Notes:
- Do not rely on `environment: digitalocean-dns` as an approval gate on Gitea 1.26.x; Gitea ignores `jobs.<job_id>.environment` instead of pausing for review.
- If a future Gitea release adds protected Actions environments, this can be revisited and the manual workflows can be collapsed into a preview job followed by an environment-gated push job.
