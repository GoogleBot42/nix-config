{ inputs }:
final: prev:

let
  system = prev.system;
in
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

  # nginx 1.30.0 -> 1.30.1: critical security fix. Pulled forward from
  # nixpkgs master (PR #519893, merged 2026-05-14) because the
  # nixos-unstable channel branch we track does not have it yet.
  # Remove once nixos-unstable advances past 2026-05-14.
  nginxStable = prev.nginxStable.overrideAttrs (old: rec {
    version = "1.30.1";
    src = prev.fetchurl {
      url = "https://nginx.org/download/nginx-${version}.tar.gz";
      hash = "sha256-mXZQANl0iWsxyliC2MJ5zj/n729cb58Kln7X/TQH+cw=";
    };
  });
  nginx = final.nginxStable;

  # Plasma Bigscreen: TV-optimized KDE shell (not yet packaged in nixpkgs)
  plasma-bigscreen = import ./plasma-bigscreen.nix {
    inherit (prev.kdePackages)
      mkKdeDerivation plasma-workspace plasma-wayland-protocols
      qtmultimedia qtwayland qtwebengine qcoro;
    inherit (prev) lib fetchFromGitLab pkg-config sdl3 libcec wayland;
  };

  # Hindsight agent-memory server. Built via uv2nix against the upstream
  # workspace; uses hermes-agent's toolchain pin to avoid duplicating uv2nix.
  hindsight-api = prev.callPackage ../pkgs/hindsight {
    hindsight-src = inputs.hindsight-src;
    uv2nix = inputs.hermes-agent.inputs.uv2nix;
    pyproject-nix = inputs.hermes-agent.inputs.pyproject-nix;
    pyproject-build-systems = inputs.hermes-agent.inputs.pyproject-build-systems;
  };
}
