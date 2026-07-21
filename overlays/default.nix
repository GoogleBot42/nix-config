{ inputs }:
final: prev:

{
  # Disable CephFS support in samba to work around upstream nixpkgs bug:
  # ceph is pinned to python3.11 which is incompatible with sphinx >= 9.1.0.
  # https://github.com/NixOS/nixpkgs/issues/442652
  samba4Full = prev.samba4Full.override { enableCephFS = false; };

  # Fix incus-lts doc build: `incus manpage` tries to create
  # ~/.config/incus, but HOME is /homeless-shelter in the nix sandbox.
  incus-lts = prev.incus-lts.overrideAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ prev.writableTmpDirAsHomeHook ];
  });

  # Skip the upstream test suite: test_amd_pstate_upower is timing-sensitive
  # ("timed out waiting for ...") and intermittently fails on loaded CI
  # runners while the same derivation builds fine elsewhere.
  power-profiles-daemon = prev.power-profiles-daemon.overrideAttrs (old: {
    doCheck = false;
    # Later flags win in meson, overriding the package's -Dtests=true
    mesonFlags = (old.mesonFlags or [ ]) ++ [ "-Dtests=false" ];
  });

  # Skip the upstream test suite: the dynamiclauncher and notification
  # (test_sound_fd sound validator subprocess) integration tests fail in the
  # nix build sandbox on our builders.
  xdg-desktop-portal = prev.xdg-desktop-portal.overrideAttrs {
    doCheck = false;
  };

  # Retry on push failure to work around hyper connection pool race condition.
  # https://github.com/zhaofengli/attic/pull/246
  attic-client = prev.attic-client.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ../patches/attic-client-push-retry.patch
    ];
  });

  # Add --zeroconf-port support to Spotify Connect plugin so librespot
  # binds to a fixed port that can be opened in the firewall.
  music-assistant = prev.music-assistant.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ../patches/music-assistant-zeroconf-port.patch
    ];
  });

  # Ignore stale Avahi pidfiles when resolvconf refreshes static DNS at boot.
  openresolv = prev.openresolv.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ../patches/openresolv-avahi-ignore-stale-pid.patch
    ];
  });

  # Plasma Bigscreen: TV-optimized KDE shell (not yet packaged in nixpkgs)
  plasma-bigscreen = import ./plasma-bigscreen.nix {
    inherit (prev.kdePackages)
      mkKdeDerivation plasma-workspace plasma-wayland-protocols
      qtmultimedia qtwayland qtwebengine qcoro;
    inherit (prev) lib fetchFromGitLab pkg-config sdl3 libcec wayland;
  };

  # Keep Logseq building after nixpkgs updates until upstream moves off
  # electron_39, which is now blocked as insecure. The yauzl patch is pulled
  # forward from nixpkgs master so Electron's zip can still be extracted under
  # the newer Node.js used by the current package set.
  logseq = (prev.logseq.override {
    electron_39 = final.electron_41;
  }).overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ../patches/logseq-bump-yauzl.patch
    ];

    yarnOfflineCacheStaticResources = prev.fetchYarnDeps {
      name = "logseq-${old.version}-yarn-deps-static-resources";
      src = old.src;
      patches = (old.patches or [ ]) ++ [
        ../patches/logseq-bump-yauzl.patch
      ];
      postPatch = "cd ./static";
      hash = "sha256-TFisR5GwcKmuddGhe0i6rAmr2wDWzed/mXnxVGARYK0=";
    };
  });

  # Vikunja 2.3.0 in nixos-unstable still asks for the package-specific
  # pnpm_10_29_2 attr, which is now blocked as insecure. Build it with the
  # current pnpm 10.x package until nixpkgs updates the Vikunja expression.
  vikunja = prev.vikunja.override {
    pnpm_10_29_2 = final.pnpm_10;
  };

  pgs = prev.callPackage ../pkgs/pgs { };

  # Hindsight agent-memory server. Built via uv2nix against the upstream
  # workspace; uses hermes-agent's toolchain pin to avoid duplicating uv2nix.
  hindsight-api = prev.callPackage ../pkgs/hindsight {
    hindsight-src = inputs.hindsight-src;
    uv2nix = inputs.hermes-agent.inputs.uv2nix;
    pyproject-nix = inputs.hermes-agent.inputs.pyproject-nix;
    pyproject-build-systems = inputs.hermes-agent.inputs.pyproject-build-systems;
  };
}
