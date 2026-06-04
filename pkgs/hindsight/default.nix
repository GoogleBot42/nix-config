{ lib
, callPackage
, python312
, stdenv
, makeWrapper

, hindsight-src
, uv2nix
, pyproject-nix
, pyproject-build-systems
}:

# Build the hindsight-api-slim venv from upstream's uv workspace.
#
# We pull only the `local-ml` extra — for local embeddings + reranker via
# sentence-transformers (codex OAuth isn't accepted for /v1/embeddings, so
# the obvious fallback is local inference). We skip `embedded-db` because
# the workspace uses system postgres.
#
# Cost: torch + transformers + flashrank etc. add a few GB to the closure
# and ~30 min to the first build. The PyTorch CPU index pin in hindsight's
# pyproject keeps us off CUDA.
let
  workspace = uv2nix.lib.workspace.loadWorkspace {
    workspaceRoot = hindsight-src;
  };

  overlay = workspace.mkPyprojectOverlay {
    sourcePreference = "wheel";
  };

  # Per-package fixups for `local-ml` deps whose Linux wheels don't
  # play nicely with auto-patchelf. mlx ships an internal `libmlx.so`
  # that lives inside the same wheel; auto-patchelf doesn't add the
  # package's own lib dir to LD_LIBRARY_PATH, so the dep search fails.
  # We never load mlx at runtime (only the `jina-mlx` reranker imports
  # it, and we use `local`), so ignore the unresolved dep at patchelf
  # time rather than fight the wheel layout.
  pythonPackageOverrides = final: prev: {
    mlx = prev.mlx.overrideAttrs (old: {
      autoPatchelfIgnoreMissingDeps = [ "libmlx.so" ];
    });
  };

  pythonSet =
    (callPackage pyproject-nix.build.packages {
      python = python312;
    }).overrideScope
      (lib.composeManyExtensions [
        pyproject-build-systems.overlays.default
        overlay
        pythonPackageOverrides
      ]);

  venv = pythonSet.mkVirtualEnv "hindsight-api-env" {
    hindsight-api-slim = [ "local-ml" ];
  };
in
stdenv.mkDerivation {
  pname = "hindsight-api";
  version = "0.7.2";

  dontUnpack = true;
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    # The venv ships hindsight-api / hindsight-worker / hindsight-admin /
    # hindsight-local-mcp / alembic in $venv/bin. Link them out so callers
    # don't have to know about the venv layout.
    for bin in hindsight-api hindsight-worker hindsight-admin hindsight-local-mcp alembic; do
      if [ -e ${venv}/bin/$bin ]; then
        ln -s ${venv}/bin/$bin $out/bin/$bin
      fi
    done
    runHook postInstall
  '';

  passthru = {
    inherit venv pythonSet;
    pythonEnv = venv;
  };

  meta = with lib; {
    description = "Hindsight: agent memory with knowledge graph and tiered retrieval";
    homepage = "https://github.com/vectorize-io/hindsight";
    license = licenses.mit;
    mainProgram = "hindsight-api";
    platforms = platforms.linux;
  };
}
