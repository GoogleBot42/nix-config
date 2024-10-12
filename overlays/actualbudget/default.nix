{ lib
, buildNpmPackage
, fetchFromGitHub
, python3
, nodejs
, runtimeShell
}:
buildNpmPackage rec {
  pname = "actual-server";
  version = "24.10.1";

  src = fetchFromGitHub {
    owner = "actualbudget";
    repo = pname;
    rev = "refs/tags/v${version}";
    hash = "sha256-VJAD+lNamwuYmiPJLXkum6piGi5zLOHBp8cUeZagb4s=";
  };

  npmDepsHash = "sha256-Z2e4+JMhI/keLerT0F4WYdLnXHRQCqL7NjNyA9SFEF8=";

  patches = [
    ./migrations-should-use-pkg-path.patch
  ];

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  dontNpmBuild = true;

  postInstall = ''
    mkdir -p $out/bin
    cat <<EOF > $out/bin/actual-server
    #!${runtimeShell}
    exec ${nodejs}/bin/node $out/lib/node_modules/actual-sync/app.js "\$@"
    EOF
    chmod +x $out/bin/actual-server
  '';
}
