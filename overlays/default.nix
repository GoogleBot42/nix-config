{ inputs }:
final: prev:

{
  # Disable CephFS support in samba to work around upstream nixpkgs bug:
  # ceph is pinned to python3.11 which is incompatible with sphinx >= 9.1.0.
  # https://github.com/NixOS/nixpkgs/issues/442652
  samba4Full = prev.samba4Full.override { enableCephFS = false; };

  # Skip the upstream test suite: test_amd_pstate_upower is timing-sensitive
  # ("timed out waiting for ...") and intermittently fails on loaded CI
  # runners while the same derivation builds fine elsewhere.
  power-profiles-daemon = prev.power-profiles-daemon.overrideAttrs (old: {
    doCheck = false;
    # Later flags win in meson, overriding the package's -Dtests=true
    mesonFlags = (old.mesonFlags or [ ]) ++ [ "-Dtests=false" ];
  });

  # Skip the upstream test suite: upower's checkPhase runs the umockdev/dbusmock
  # integration tests via `meson test`, and ~two dozen of them hit the meson
  # per-test timeout on loaded CI runners (all TIMEOUT, none Fail), while the
  # same derivation builds fine elsewhere. doCheck = false skips the whole
  # checkPhase, including its preCheck/postCheck libupower-glib.so symlink dance.
  upower = prev.upower.overrideAttrs {
    doCheck = false;
    doInstallCheck = false;
  };

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

  # Add a fixed zeroconf-port option to the Spotify Connect plugin so
  # discovery binds to a stable port that can be opened in the firewall. As of
  # MA 2.9.x the plugin drives go-librespot via a config.yml, so the option now
  # sets go-librespot's `zeroconf_port` key (0 = random) instead of a CLI flag.
  # Purpose: pinning the port lets it be allowed in the firewall, which stops
  # logRefusedConnections dmesg spam from the network-facing discovery listener.
  # The pinned values live in the MA UI per provider instance and must match the
  # ports opened in machines/storage/s0/home-automation.nix.
  music-assistant = prev.music-assistant.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ../patches/music-assistant-zeroconf-port.patch
    ];
    # test_emit_does_no_disk_io asserts logging never touches disk, but linecache
    # legitimately reads source files present in the store build, so it fails in
    # the sandbox. Unrelated to our patch; skip it.
    disabledTests = (old.disabledTests or [ ]) ++ [
      "test_emit_does_no_disk_io"
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

  # Keep Logseq building until upstream moves off electron_39, which is now
  # blocked as insecure (EOL). The yauzl fix we used to carry forward as
  # logseq-bump-yauzl.patch is now applied by nixpkgs itself
  # (pkgs/by-name/lo/logseq/package.nix: ./bump-yauzl.patch), so the override
  # is just the electron bump now.
  logseq = prev.logseq.override {
    electron_39 = final.electron_41;
  };

  # cheetah3 is published upstream under the distribution name "ct3" (its
  # wheel metadata is ct3-*.dist-info), but nixpkgs sets pname = "cheetah3".
  # The pythonMetadataCheckHook looks up importlib.metadata.version("cheetah3")
  # and fails with PackageNotFoundError. Skip that check until nixpkgs aligns
  # the pname with the real dist name. Pulled in via esphome on s0.
  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (pyfinal: pyprev: {
      cheetah3 = pyprev.cheetah3.overrideAttrs (_: {
        dontCheckPythonMetadata = true;
      });
    })
  ];

  # deskflow's SettingsTests::checkValidSettings asserts a locale-derived
  # default that QLocale resolves to "" in the build sandbox (no system
  # locale), so the test expects "ko" but gets "". Skip just that suite in
  # checkPhase; every other unit test still runs. Drop once upstream makes
  # the test sandbox-independent.
  deskflow = prev.deskflow.overrideAttrs (old: {
    checkPhase = ''
      runHook preCheck

      export QT_QPA_PLATFORM=offscreen
      ctest --test-dir "src/unittests" --output-on-failure -E SettingsTests
      ./bin/legacytests

      runHook postCheck
    '';
  });

  pgs = prev.callPackage ../pkgs/pgs { };

  # Hindsight agent-memory server, from the source-built hindsight-nix flake.
  hindsight-api = inputs.hindsight-nix.packages.${prev.stdenv.hostPlatform.system}.hindsight-api;
}
