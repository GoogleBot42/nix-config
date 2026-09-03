# Build/Eval Gotchas

## aarch64 machines: neither eval nor build works from this workspace

This workspace has no aarch64 builders and no binfmt_misc/qemu emulation
registered (`ls /proc/sys/fs/binfmt_misc/` is empty, no `qemu-aarch64*`
binary on PATH, no `/etc/nix/machines`). `nix.conf` does list
`extra-platforms = aarch64-linux`, so the daemon will *accept* an
aarch64-linux build job, but with nothing to actually execute it the build
just fails — the setting alone is not evidence that aarch64 builds work
here.

On top of that, `flake.nix`'s nixpkgs-patching mechanism can force a real
aarch64 *build* even for pure evaluation. `nixpkgsFor` in `flake.nix` calls
`patchNixpkgs system` once per entry in `supportedSystems`
(`x86_64-linux` and `aarch64-linux`), and `patchNixpkgs` applies patches via
`nixpkgs.legacyPackages.${system}.applyPatches`, i.e. a `runCommand`-style
derivation built with *that target system's* stdenv. So for an
`aarch64-linux` machine, evaluating its config pulls in an
`aarch64-linux` `applyPatches` derivation, which is import-from-derivation
— evaluation itself blocks on building that derivation. (Right now
`nixpkgsPatches` in `flake.nix` is `[ ]`, so the `if nixpkgsPatches == [ ]
then nixpkgs else patchNixpkgs system` branch skips this and evaluation of
an aarch64 machine would currently succeed without a real build. The moment
that list becomes non-empty again, aarch64 eval requires an aarch64 build.
Don't assume the list is still empty — check `flake.nix` before relying on
this.)

**Workaround for eval-only checks** (e.g. rendering a machine's config to
inspect an option value, sanity-checking a refactor): in a scratch git
worktree, temporarily change the machine's `arch` in its `properties.nix`
and any `nixpkgs.hostPlatform` setting to `x86_64-linux`, run the
evaluation you need against that worktree, then discard the worktree.

```bash
git worktree add <scratchpad>/scratch-eval-<hostname> <branch>
cd <scratchpad>/scratch-eval-<hostname>
# edit machines/<hostname>/properties.nix: arch = "x86_64-linux";
# edit any nixpkgs.hostPlatform = "aarch64-linux"; to "x86_64-linux"; if present
nix eval .#nixosConfigurations.<hostname>.config.<option> --json
cd -
git worktree remove --force <scratchpad>/scratch-eval-<hostname>
```

**Warning:** this only produces an x86_64-shaped evaluation of the
machine. It does not verify anything about the real aarch64 build — option
defaults, package selection, and conditionals can all differ by
`hostPlatform.system`. Never present output from this workaround as
verified for the actual aarch64 target; use it only to sanity-check things
that are provably architecture-independent (e.g. a string value computed
from non-platform-dependent inputs), and say so explicitly when reporting
results.

## i686/32-bit leaf derivations (e.g. Steam FHS envs)

The nix daemon's `extra-platforms` does not include `i686-linux` — verify
the current value before assuming otherwise:

```bash
nix config show extra-platforms
# or: grep extra-platforms /etc/nix/nix.conf
```

`googlebot` is listed in `trusted-users` (`nix.conf`), though, so it can
override `extra-platforms` per-invocation. For a 32-bit derivation that
isn't in the upstream binary cache — which happens for anything under the
patched nixpkgs tree, since patching shifts store-path hashes and upstream
caches miss — build it directly with:

```bash
nix build --extra-platforms i686-linux .#<attr> --no-link
```

This works because the daemon executes i686-linux code directly on an
x86_64-linux host (no emulation needed, just a permissive platform
allowlist), and a trusted user is allowed to widen `extra-platforms` for
the invocation.

## Expected long local builds (not regressions)

Run `nix flake update` and every machine build with `run_in_background` —
the update alone can exceed the Bash tool's 10-minute foreground timeout
while unpacking inputs, and the builds below take hours.

- **fry and howl rebuild Firefox from source on every update.**
  `common/pc/firefox.nix` overrides `firefox-unwrapped` with
  `privacySupport = true`, so the result is never in cache.nixos.org, and
  the build is PGO (two compile passes plus an xvfb profiling run) — about
  two hours on this workspace. Both machines share the derivation, so the
  second one waits on the first's lock; that is not a hang.
- **s0 compiles Ceph and its Python 3.12 closure.** `sambaFull` pulls in
  ceph, which pins `python312`; hydra does not fully cache that interpreter's
  package set, so the whole `openai -> sqlframe -> narwhals -> ...` chain
  builds here and any upstream test flake in it fails the s0 build.
- **zoidberg needs `--extra-platforms i686-linux`** (see above) for Steam.

## Scoping Python test-skip overrides

When a locally-built Python package fails its tests, do NOT skip them via a
global `pythonPackagesExtensions` entry. Many test-only packages
(`inline-snapshot` is a check input of `pydantic`) sit in the closure of
widely cached libraries, so a global override changes their store paths on
every interpreter, invalidates the upstream cache for the whole downstream
set, and surfaces a cascade of unrelated local test failures. Scope the
override to the interpreter that is actually uncached instead:

```nix
python312 = prev.python312.override {
  packageOverrides = pyfinal: pyprev: { <pkg> = pyprev.<pkg>.overridePythonAttrs (...); };
};
```

Verify the scope before rebuilding: the default interpreter's `pydantic`
`outPath` must be unchanged and still return 200 from
`https://cache.nixos.org/<hash>.narinfo`.
