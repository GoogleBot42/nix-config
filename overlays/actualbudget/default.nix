{ lib
, buildNpmPackage
, fetchFromGitHub
, python3
, nodejs
, runtimeShell
}:
buildNpmPackage rec {
  pname = "actual-server";
  version = "24.2.0";

  src = fetchFromGitHub {
    owner = "actualbudget";
    repo = pname;
    rev = "refs/tags/v${version}";
    hash = "sha256-9Dx6FxWZvGAgJfYYuEgkLr5dhpe5P+bdiSQWhPVeUu8=";
  };

  npmDepsHash = "sha256-j9i+Z6ZlywwCgs198bt9jOwVxe1Rhh7EQVH3ZJ+YNI4=";

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
